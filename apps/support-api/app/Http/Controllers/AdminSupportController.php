<?php

namespace App\Http\Controllers;

use App\Auth\SupportActorContext;
use App\Models\SupportActor;
use App\Models\SupportAgentState;
use App\Models\SupportCategory;
use App\Models\SupportFaq;
use App\Models\SupportMessage;
use App\Models\SupportTicket;
use App\Services\SupportAuditService;
use App\Services\SupportAssignmentService;
use App\Services\SupportIdempotencyService;
use App\Services\SupportPresenter;
use App\Services\SupportTicketService;
use DateTimeInterface;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Routing\Controller;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Str;
use Illuminate\Validation\Rule;
use RuntimeException;

class AdminSupportController extends Controller
{
    public function __construct(
        private readonly SupportPresenter $presenter,
        private readonly SupportTicketService $tickets,
        private readonly SupportAssignmentService $assignments,
        private readonly SupportIdempotencyService $idempotency,
        private readonly SupportAuditService $audit,
    ) {
    }

    public function bootstrap(Request $request): JsonResponse
    {
        $context = $this->context($request);
        $state = SupportAgentState::query()
            ->where('tenant_id', $context->tenantId())
            ->where('admin_actor_id', $context->actor->id)
            ->first();
        $settings = DB::table('support_settings')->where('tenant_id', $context->tenantId())->first();
        $canViewAllTickets = $context->hasPermission('support_ticket.view_all');

        return response()->json([
            'permissions' => $context->permissions(),
            'agent_state' => [
                'available' => (bool) ($state?->available ?? false),
                'capacity' => (int) ($state?->capacity ?? $settings?->default_agent_capacity ?? 3),
                'last_heartbeat_at' => $state?->last_heartbeat_at?->toIso8601String(),
            ],
            'limits' => [
                'attachments_per_message' => min(4, max(1, (int) (
                    $settings?->max_attachments_per_message
                        ?? config('support.attachments.max_files', 4)
                ))),
                'attachment_bytes' => min(8 * 1024 * 1024, max(1024, (int) (
                    $settings?->max_attachment_bytes
                        ?? config('support.attachments.max_bytes', 8 * 1024 * 1024)
                ))),
            ],
            'counts' => [
                'mine' => SupportTicket::query()->where('tenant_id', $context->tenantId())
                    ->where('assigned_admin_actor_id', $context->actor->id)->where('status', '!=', 'closed')->count(),
                'queue' => $canViewAllTickets
                    ? SupportTicket::query()->where('tenant_id', $context->tenantId())->where('status', 'queued')->count()
                    : 0,
                'all_open' => $canViewAllTickets
                    ? SupportTicket::query()->where('tenant_id', $context->tenantId())->where('status', '!=', 'closed')->count()
                    : 0,
                'closed' => $canViewAllTickets
                    ? SupportTicket::query()->where('tenant_id', $context->tenantId())->where('status', 'closed')->count()
                    : 0,
            ],
        ]);
    }

    public function index(Request $request): JsonResponse
    {
        $context = $this->requirePermission($request, 'support_ticket.view_assigned');
        $view = trim((string) $request->query('view', 'mine'));
        $limit = min(100, max(1, (int) $request->query('limit', 30)));
        $cursor = trim((string) $request->query('cursor', ''));
        $query = SupportTicket::query()->where('tenant_id', $context->tenantId());

        if ($view === 'queue') {
            $this->requirePermission($request, 'support_ticket.view_all');
            $query->where('status', 'queued');
        } elseif ($view === 'closed') {
            $this->requirePermission($request, 'support_ticket.view_all');
            $query->where('status', 'closed');
        } elseif ($view === 'all') {
            $this->requirePermission($request, 'support_ticket.view_all');
            $query->where('status', '!=', 'closed');
        } else {
            $query->where('assigned_admin_actor_id', $context->actor->id)->where('status', '!=', 'closed');
        }
        if ($cursor !== '') {
            $query->where('id', $view === 'queue' ? '>' : '<', $cursor);
        }
        $view === 'queue'
            ? $query->orderBy('id')
            : $query->orderByDesc('priority')->orderByDesc('id');
        $items = $query->limit($limit + 1)->get();
        $hasMore = $items->count() > $limit;
        $page = $items->take($limit);

        return response()->json([
            'data' => $page->map(fn (SupportTicket $ticket): array => $this->presenter->ticket($ticket, $context, true))->all(),
            'next_cursor' => $hasMore ? (string) $page->last()?->id : null,
        ]);
    }

    public function show(Request $request, string $ticket): JsonResponse
    {
        $context = $this->context($request);
        $resource = $this->findVisibleTicket($context, $ticket);

        return response()->json(['ticket' => $this->presenter->ticket($resource, $context, true)]);
    }

    public function messages(Request $request, string $ticket): JsonResponse
    {
        $context = $this->context($request);
        $resource = $this->findVisibleTicket($context, $ticket);
        $before = max(0, (int) $request->query('before_sequence', 0));
        $limit = min(100, max(1, (int) $request->query('limit', 50)));
        $query = SupportMessage::query()->where('ticket_id', $resource->id);
        if ($before > 0) {
            $query->where('sequence', '<', $before);
        }
        $items = $query->orderByDesc('sequence')->limit($limit + 1)->get();
        $hasMore = $items->count() > $limit;
        $page = $items->take($limit)->sortBy('sequence')->values();

        return response()->json([
            'data' => $page->map(fn (SupportMessage $message): array => $this->presenter->message($message, $context))->all(),
            'next_before_sequence' => $hasMore ? (int) $page->first()?->sequence : null,
        ]);
    }

    public function sendMessage(Request $request, string $ticket): JsonResponse
    {
        $context = $this->requirePermission($request, 'support_ticket.reply_assigned');
        $resource = $this->findVisibleTicket($context, $ticket);
        [$maxAttachments, $maxAttachmentKilobytes] = $this->attachmentLimits($context);
        $payload = $request->validate([
            'body' => ['nullable', 'string', 'max:4000', 'required_without:attachments'],
            'attachments' => [
                'sometimes',
                'array',
                'max:'.$maxAttachments,
                'required_without:body',
            ],
            'attachments.*' => [
                'file',
                'mimes:jpeg,jpg,png,webp',
                'max:'.$maxAttachmentKilobytes,
            ],
        ]);
        $files = $request->file('attachments', []);
        $body = trim((string) ($payload['body'] ?? ''));
        $key = $this->idempotencyKey($request);

        return $this->idempotent($context, 'admin.message.create', $key, [
            'ticket_id' => $resource->id,
            'body' => $body,
            'attachment_count' => is_array($files) ? count($files) : 0,
        ], function () use ($resource, $context, $body, $files): array {
            $message = $this->tickets->sendMessage($resource, $context, $body, is_array($files) ? $files : []);

            return [201, ['message' => $this->presenter->message($message, $context)]];
        });
    }

    public function markRead(Request $request, string $ticket): JsonResponse
    {
        $context = $this->context($request);
        $resource = $this->findVisibleTicket($context, $ticket);
        $payload = $request->validate(['sequence' => ['required', 'integer', 'min:0']]);
        $key = $this->idempotencyKey($request);

        return $this->idempotent($context, 'admin.ticket.read', $key, [
            'ticket_id' => $resource->id,
            'sequence' => (int) $payload['sequence'],
        ], function () use ($resource, $context, $payload): array {
            return [200, [
                'last_read_sequence' => $this->tickets->markRead(
                    $resource,
                    $context,
                    (int) $payload['sequence'],
                ),
            ]];
        });
    }

    public function waitingCustomer(Request $request, string $ticket): JsonResponse
    {
        $context = $this->requirePermission($request, 'support_ticket.reply_assigned');
        $resource = $this->findVisibleTicket($context, $ticket);
        $key = $this->idempotencyKey($request);

        return $this->idempotent($context, 'admin.ticket.waiting_customer', $key, [
            'ticket_id' => $resource->id,
        ], function () use ($resource, $context): array {
            $updated = $this->tickets->markWaitingCustomer($resource, $context);
            $this->audit->record(
                $context,
                'admin.ticket.waiting_customer',
                'ticket',
                (string) $updated->id,
            );

            return [200, ['ticket' => $this->presenter->ticket($updated, $context)]];
        });
    }

    public function close(Request $request, string $ticket): JsonResponse
    {
        $context = $this->requirePermission($request, 'support_ticket.close_assigned');
        $resource = $this->findVisibleTicket($context, $ticket);
        $payload = $request->validate(['reason' => ['nullable', 'string', 'max:500']]);
        $key = $this->idempotencyKey($request);

        return $this->idempotent($context, 'admin.ticket.close', $key, [
            'ticket_id' => $resource->id,
            'reason' => trim((string) ($payload['reason'] ?? '')),
        ], function () use ($resource, $context, $payload): array {
            $wasClosed = $resource->status === 'closed';
            $closed = $this->tickets->close($resource, $context, trim((string) ($payload['reason'] ?? '')) ?: null);
            if (! $wasClosed) {
                $this->audit->record(
                    $context,
                    'admin.ticket.close',
                    'ticket',
                    (string) $closed->id,
                );
            }

            return [200, ['ticket' => $this->presenter->ticket($closed, $context)]];
        });
    }

    public function assign(Request $request, string $ticket): JsonResponse
    {
        $context = $this->requirePermission($request, 'support_ticket.assign');
        $resource = SupportTicket::query()
            ->where('tenant_id', $context->tenantId())
            ->whereKey($ticket)
            ->firstOrFail();
        $payload = $request->validate([
            'admin_actor_id' => [
                'required',
                'string',
                Rule::exists('support_actors', 'id')->where(
                    fn ($query) => $query->where('tenant_id', $context->tenantId())->where('actor_type', 'admin')->where('status', 'active'),
                ),
            ],
            'reason' => ['nullable', 'string', 'max:500'],
        ]);
        $agent = SupportActor::query()->findOrFail($payload['admin_actor_id']);
        $key = $this->idempotencyKey($request);

        return $this->idempotent($context, 'admin.ticket.assign', $key, [
            'ticket_id' => $resource->id,
            'admin_actor_id' => $agent->id,
            'reason' => trim((string) ($payload['reason'] ?? '')),
        ], function () use ($resource, $agent, $context, $payload): array {
            $assigned = $this->assignments->assign($resource, $agent, 'admin', $context->actor, trim((string) ($payload['reason'] ?? '')) ?: null);
            if ($assigned) {
                $this->audit->record(
                    $context,
                    'admin.ticket.assign',
                    'ticket',
                    (string) $resource->id,
                    ['admin_actor_id' => (string) $agent->id],
                );
            }

            return [200, ['ticket' => $this->presenter->ticket($resource->fresh(), $context)]];
        });
    }

    public function agentState(Request $request): JsonResponse
    {
        $context = $this->requirePermission($request, 'support_ticket.reply_assigned');
        $payload = $request->validate([
            'available' => ['required', 'boolean'],
            'capacity' => ['nullable', 'integer', 'between:1,20'],
        ]);
        $key = $this->idempotencyKey($request);

        return $this->idempotent($context, 'admin.agent_state.update', $key, [
            'available' => (bool) $payload['available'],
            'capacity' => $payload['capacity'] ?? null,
        ], function () use ($context, $payload): array {
            $timestamp = now();
            DB::table('support_agent_states')->upsert([
                [
                    'tenant_id' => $context->tenantId(),
                    'admin_actor_id' => $context->actor->id,
                    'available' => (bool) $payload['available'],
                    'capacity' => $payload['capacity'] ?? null,
                    'last_heartbeat_at' => $timestamp,
                    'created_at' => $timestamp,
                    'updated_at' => $timestamp,
                ],
            ], ['tenant_id', 'admin_actor_id'], ['available', 'capacity', 'last_heartbeat_at', 'updated_at']);
            if ((bool) $payload['available']) {
                $this->assignments->drainTenant($context->tenantId());
            }
            $this->audit->record(
                $context,
                'admin.agent_state.update',
                'agent',
                (string) $context->actor->id,
                [
                    'available' => (bool) $payload['available'],
                    'capacity' => $payload['capacity'] ?? null,
                ],
            );

            return [200, [
                'available' => (bool) $payload['available'],
                'capacity' => $payload['capacity'] ?? null,
                'last_heartbeat_at' => $timestamp->toIso8601String(),
            ]];
        });
    }

    public function heartbeat(Request $request): JsonResponse
    {
        $context = $this->requirePermission($request, 'support_ticket.reply_assigned');
        $key = $this->idempotencyKey($request);

        return $this->idempotent(
            $context,
            'admin.agent_state.heartbeat',
            $key,
            [],
            function () use ($context): array {
                $timestamp = now();
                DB::table('support_agent_states')
                    ->where('tenant_id', $context->tenantId())
                    ->where('admin_actor_id', $context->actor->id)
                    ->update([
                        'last_heartbeat_at' => $timestamp,
                        'updated_at' => $timestamp,
                    ]);

                return [200, ['heartbeat_at' => $timestamp->toIso8601String()]];
            },
        );
    }

    public function agents(Request $request): JsonResponse
    {
        $context = $this->context($request);
        abort_unless(
            $context->hasPermission('support_agent.manage')
                || $context->hasPermission('support_ticket.assign')
                || $context->hasPermission('support_ticket.view_all'),
            403,
        );
        $agents = SupportActor::query()
            ->where('tenant_id', $context->tenantId())
            ->where('actor_type', 'admin')
            ->orderBy('display_name')
            ->get();
        $data = $agents->map(function (SupportActor $agent) use ($context): array {
            $state = SupportAgentState::query()
                ->where('tenant_id', $context->tenantId())
                ->where('admin_actor_id', $agent->id)
                ->first();

            return [
                'id' => (string) $agent->id,
                'external_id' => (string) $agent->external_id,
                'name' => (string) ($agent->display_name ?? ''),
                'available' => (bool) ($state?->available ?? false),
                'capacity' => $state?->capacity,
                'last_heartbeat_at' => $state?->last_heartbeat_at?->toIso8601String(),
                'active_tickets' => SupportTicket::query()
                    ->where('tenant_id', $context->tenantId())
                    ->where('assigned_admin_actor_id', $agent->id)
                    ->where('status', '!=', 'closed')
                    ->count(),
            ];
        })->all();

        return response()->json(['data' => $data]);
    }

    public function updateAgentState(Request $request, string $agent): JsonResponse
    {
        $context = $this->requirePermission($request, 'support_agent.manage');
        $resource = SupportActor::query()
            ->where('tenant_id', $context->tenantId())
            ->where('actor_type', 'admin')
            ->where('status', 'active')
            ->whereKey($agent)
            ->firstOrFail();
        $payload = $request->validate([
            'capacity' => ['required', 'integer', 'between:1,20'],
        ]);
        $key = $this->idempotencyKey($request);

        return $this->idempotent($context, 'admin.agent_state.manage', $key, [
            'admin_actor_id' => $resource->id,
            'capacity' => (int) $payload['capacity'],
        ], function () use ($context, $resource, $payload): array {
            $timestamp = now();
            DB::table('support_agent_states')->upsert([
                [
                    'tenant_id' => $context->tenantId(),
                    'admin_actor_id' => $resource->id,
                    'available' => false,
                    'capacity' => (int) $payload['capacity'],
                    'created_at' => $timestamp,
                    'updated_at' => $timestamp,
                ],
            ], ['tenant_id', 'admin_actor_id'], ['capacity', 'updated_at']);
            $this->audit->record(
                $context,
                'admin.agent_state.manage',
                'agent',
                (string) $resource->id,
                ['capacity' => (int) $payload['capacity']],
            );

            return [200, [
                'agent_id' => (string) $resource->id,
                'capacity' => (int) $payload['capacity'],
            ]];
        });
    }

    public function categories(Request $request): JsonResponse
    {
        $context = $this->requirePermission($request, 'support_faq.view');
        $locale = trim(explode(',', (string) $request->header('Accept-Language', 'th-TH'))[0]) ?: 'th-TH';

        return response()->json([
            'data' => SupportCategory::query()
                ->where('tenant_id', $context->tenantId())
                ->orderBy('sort_order')
                ->get()
                ->map(fn (SupportCategory $category): array => [
                    ...$this->presenter->category($category, $locale),
                    'name_json' => $category->name_json,
                    'status' => (string) $category->status,
                    'sort_order' => (int) $category->sort_order,
                ])
                ->all(),
        ]);
    }

    public function saveCategory(Request $request, ?string $category = null): JsonResponse
    {
        $context = $this->requirePermission($request, 'support_faq.manage');
        $payload = $request->validate([
            'code' => ['required', 'string', 'max:80'],
            'name_json' => ['required', 'array'],
            'name_json.th-TH' => ['nullable', 'string', 'max:200'],
            'name_json.en-US' => ['nullable', 'string', 'max:200'],
            'icon_key' => ['nullable', 'string', 'max:80'],
            'is_fallback' => ['sometimes', 'boolean'],
            'status' => ['required', Rule::in(['active', 'inactive'])],
            'sort_order' => ['sometimes', 'integer', 'min:0'],
        ]);
        $resource = $category === null
            ? new SupportCategory(['id' => 'sca_'.Str::ulid()->toBase32(), 'tenant_id' => $context->tenantId()])
            : SupportCategory::query()->where('tenant_id', $context->tenantId())->whereKey($category)->firstOrFail();
        $key = $this->idempotencyKey($request);
        $operation = $category === null ? 'admin.category.create' : 'admin.category.update';

        return $this->idempotent($context, $operation, $key, [
            'category_id' => $category,
            ...$payload,
        ], function () use ($resource, $payload, $category, $context, $operation): array {
            $resource->fill($payload)->save();
            $this->audit->record(
                $context,
                $operation,
                'category',
                (string) $resource->id,
                ['status' => (string) $resource->status],
            );

            return [$category === null ? 201 : 200, ['category' => $resource->toArray()]];
        });
    }

    public function faqs(Request $request): JsonResponse
    {
        $context = $this->requirePermission($request, 'support_faq.view');

        return response()->json([
            'data' => SupportFaq::query()
                ->where('tenant_id', $context->tenantId())
                ->orderBy('sort_order')
                ->orderByDesc('updated_at')
                ->get(),
        ]);
    }

    public function saveFaq(Request $request, ?string $faq = null): JsonResponse
    {
        $context = $this->requirePermission($request, 'support_faq.manage');
        $payload = $request->validate([
            'category_id' => [
                'nullable',
                'string',
                Rule::exists('support_categories', 'id')->where(fn ($query) => $query->where('tenant_id', $context->tenantId())),
            ],
            'question_json' => ['required', 'array'],
            'answer_json' => ['required', 'array'],
            'keywords_json' => ['nullable', 'array'],
            'status' => ['required', Rule::in(['draft', 'published', 'archived'])],
            'sort_order' => ['sometimes', 'integer', 'min:0'],
        ]);
        $resource = $faq === null
            ? new SupportFaq(['id' => 'sfq_'.Str::ulid()->toBase32(), 'tenant_id' => $context->tenantId()])
            : SupportFaq::query()->where('tenant_id', $context->tenantId())->whereKey($faq)->firstOrFail();
        $payload['published_at'] = $payload['status'] === 'published'
            ? ($resource->published_at ?? now())
            : null;
        $key = $this->idempotencyKey($request);
        $operation = $faq === null ? 'admin.faq.create' : 'admin.faq.update';

        return $this->idempotent($context, $operation, $key, [
            'faq_id' => $faq,
            ...$payload,
        ], function () use ($resource, $payload, $faq, $context, $operation): array {
            $resource->fill($payload)->save();
            $this->audit->record(
                $context,
                $operation,
                'faq',
                (string) $resource->id,
                ['status' => (string) $resource->status],
            );

            return [$faq === null ? 201 : 200, ['faq' => $resource->toArray()]];
        });
    }

    public function settings(Request $request): JsonResponse
    {
        $context = $this->requirePermission($request, 'support_agent.manage');
        $resource = DB::table('support_settings')->where('tenant_id', $context->tenantId())->first();
        $settings = $resource === null ? null : (array) $resource;
        if (is_string($settings['content_json'] ?? null)) {
            $settings['content_json'] = json_decode((string) $settings['content_json'], true);
        }

        return response()->json(['settings' => $settings]);
    }

    public function updateSettings(Request $request): JsonResponse
    {
        $context = $this->requirePermission($request, 'support_agent.manage');
        $payload = $request->validate([
            'enabled' => ['required', 'boolean'],
            'default_agent_capacity' => ['required', 'integer', 'between:1,20'],
            'max_attachments_per_message' => ['required', 'integer', 'between:1,4'],
            'max_attachment_bytes' => ['required', 'integer', 'between:1024,8388608'],
            'content_json' => ['nullable', 'array'],
        ]);
        $key = $this->idempotencyKey($request);

        return $this->idempotent($context, 'admin.settings.update', $key, $payload, function () use ($context, $payload): array {
            DB::table('support_settings')->where('tenant_id', $context->tenantId())->update([
                ...$payload,
                'content_json' => isset($payload['content_json']) ? json_encode($payload['content_json'], JSON_UNESCAPED_UNICODE) : null,
                'updated_at' => now(),
            ]);
            $settings = DB::table('support_settings')->where('tenant_id', $context->tenantId())->first();
            $settingsPayload = $settings === null ? null : (array) $settings;
            if (is_string($settingsPayload['content_json'] ?? null)) {
                $settingsPayload['content_json'] = json_decode((string) $settingsPayload['content_json'], true);
            }
            $this->audit->record(
                $context,
                'admin.settings.update',
                'settings',
                $context->tenantId(),
                [
                    'enabled' => (bool) $payload['enabled'],
                    'default_agent_capacity' => (int) $payload['default_agent_capacity'],
                    'max_attachments_per_message' => (int) $payload['max_attachments_per_message'],
                    'max_attachment_bytes' => (int) $payload['max_attachment_bytes'],
                ],
            );

            return [200, ['settings' => $settingsPayload]];
        });
    }

    public function reports(Request $request): JsonResponse
    {
        $context = $this->context($request);
        abort_unless(
            $context->hasPermission('support_report.view')
                || $context->hasPermission('support_ticket.view_assigned'),
            403,
        );

        $days = min(365, max(1, (int) $request->query('days', 30)));
        $from = now()->subDays($days);
        $canViewTeam = $context->hasPermission('support_report.view')
            && $context->hasPermission('support_ticket.view_all');
        $requestedActorId = trim((string) $request->query('actor_id', ''));
        $actorId = $canViewTeam ? $requestedActorId : $context->actor->id;
        $actor = $actorId === ''
            ? null
            : SupportActor::query()
                ->where('tenant_id', $context->tenantId())
                ->where('actor_type', 'admin')
                ->whereKey($actorId)
                ->firstOrFail();
        $agents = collect();
        $agentReports = [];

        if ($canViewTeam) {
            $agents = SupportActor::query()
                ->where('tenant_id', $context->tenantId())
                ->where('actor_type', 'admin')
                ->where('status', 'active')
                ->orderBy('display_name')
                ->orderBy('external_id')
                ->get()
                ->filter(function (SupportActor $candidate) use ($context): bool {
                    $permissions = is_array($candidate->permissions_json)
                        ? $candidate->permissions_json
                        : [];

                    return in_array('support_ticket.reply_assigned', $permissions, true)
                        || SupportTicket::query()
                            ->where('tenant_id', $context->tenantId())
                            ->where('assigned_admin_actor_id', $candidate->id)
                            ->exists();
                })
                ->values();

            if ($actor === null) {
                $agentReports = $agents
                    ->map(fn (SupportActor $candidate): array => [
                        'actor' => $this->reportActor($candidate),
                        ...$this->supportReportMetrics(
                            $context->tenantId(),
                            $from,
                            $candidate->id,
                        ),
                    ])
                    ->sortByDesc(fn (array $row): array => [
                        $row['tickets_closed'],
                        $row['tickets_assigned'],
                        $row['average_rating'],
                    ])
                    ->values()
                    ->all();
            }
        }

        return response()->json([
            'period_days' => $days,
            'scope' => $actor === null
                ? 'overview'
                : ($actor->id === $context->actor->id ? 'self' : 'agent'),
            'can_view_team' => $canViewTeam,
            'actor' => $actor === null ? null : $this->reportActor($actor),
            ...$this->supportReportMetrics($context->tenantId(), $from, $actor?->id),
            'agents' => $agents
                ->map(fn (SupportActor $candidate): array => $this->reportActor($candidate))
                ->all(),
            'agent_reports' => $agentReports,
        ]);
    }

    /**
     * @return array{
     *     tickets_opened: int,
     *     tickets_assigned: int,
     *     tickets_closed: int,
     *     average_first_response_seconds: int,
     *     average_rating: float
     * }
     */
    private function supportReportMetrics(
        string $tenantId,
        DateTimeInterface $from,
        ?string $actorId,
    ): array {
        $base = SupportTicket::query()
            ->where('tenant_id', $tenantId)
            ->where('created_at', '>=', $from);
        if ($actorId !== null) {
            $base->where('assigned_admin_actor_id', $actorId);
        }
        $ticketCount = (clone $base)->count();
        $ratingQuery = DB::table('support_ratings')
            ->join('support_tickets', 'support_tickets.id', '=', 'support_ratings.ticket_id')
            ->where('support_ratings.tenant_id', $tenantId)
            ->where('support_ratings.created_at', '>=', $from);
        if ($actorId !== null) {
            $ratingQuery->where('support_tickets.assigned_admin_actor_id', $actorId);
        }

        return [
            'tickets_opened' => $actorId === null ? $ticketCount : 0,
            'tickets_assigned' => $actorId === null ? 0 : $ticketCount,
            'tickets_closed' => (clone $base)->where('status', 'closed')->count(),
            'average_first_response_seconds' => (int) ((clone $base)
                ->whereNotNull('first_response_at')
                ->selectRaw('avg(extract(epoch from (first_response_at - created_at))) as seconds')
                ->value('seconds') ?? 0),
            'average_rating' => (float) ($ratingQuery->avg('support_ratings.stars') ?? 0),
        ];
    }

    /**
     * @return array{id: string, external_id: string, name: string}
     */
    private function reportActor(SupportActor $actor): array
    {
        return [
            'id' => (string) $actor->id,
            'external_id' => (string) $actor->external_id,
            'name' => trim((string) $actor->display_name) ?: (string) $actor->external_id,
        ];
    }

    private function context(Request $request): SupportActorContext
    {
        /** @var SupportActorContext $context */
        $context = $request->attributes->get('support_actor');

        return $context;
    }

    private function requirePermission(Request $request, string $permission): SupportActorContext
    {
        $context = $this->context($request);
        abort_unless($context->hasPermission($permission), 403);

        return $context;
    }

    private function findVisibleTicket(SupportActorContext $context, string $ticket): SupportTicket
    {
        $resource = SupportTicket::query()->where('tenant_id', $context->tenantId())->whereKey($ticket)->firstOrFail();
        abort_unless(
            $context->hasPermission('support_ticket.view_all') || $resource->assigned_admin_actor_id === $context->actor->id,
            403,
        );

        return $resource;
    }

    private function idempotencyKey(Request $request): string
    {
        $key = trim((string) $request->header('Idempotency-Key'));
        abort_if($key === '' || mb_strlen($key) > 160, 422, 'A valid Idempotency-Key header is required.');

        return $key;
    }

    /**
     * @return array{0: int, 1: int}
     */
    private function attachmentLimits(SupportActorContext $context): array
    {
        $settings = DB::table('support_settings')
            ->where('tenant_id', $context->tenantId())
            ->first();
        $maxAttachments = min(4, max(1, (int) (
            $settings->max_attachments_per_message
                ?? config('support.attachments.max_files', 4)
        )));
        $maxBytes = min(8 * 1024 * 1024, max(1024, (int) (
            $settings->max_attachment_bytes
                ?? config('support.attachments.max_bytes', 8 * 1024 * 1024)
        )));

        return [$maxAttachments, (int) ceil($maxBytes / 1024)];
    }

    /**
     * @param array<string, mixed> $payload
     * @param callable(): array{0: int, 1: array<string, mixed>} $callback
     */
    private function idempotent(
        SupportActorContext $context,
        string $operation,
        string $key,
        array $payload,
        callable $callback,
    ): JsonResponse {
        try {
            $replay = $this->idempotency->replay($context, $operation, $key, $payload);
            if ($replay !== null) {
                return response()->json($replay['body'], $replay['status']);
            }
            $concurrentReplay = $this->idempotency->begin(
                $context,
                $operation,
                $key,
                $payload,
            );
            if ($concurrentReplay !== null) {
                return response()->json(
                    $concurrentReplay['body'],
                    $concurrentReplay['status'],
                );
            }
            [$status, $body] = $callback();
            $this->idempotency->finish($context, $operation, $key, $status, $body);

            return response()->json($body, $status);
        } catch (RuntimeException $exception) {
            if ($exception->getMessage() === 'idempotency_conflict') {
                return response()->json(['error' => ['code' => 'idempotency_conflict']], 409);
            }
            if ($exception->getMessage() === 'idempotency_in_progress') {
                return response()->json(['error' => ['code' => 'request_in_progress']], 409);
            }
            $this->idempotency->abandon($context, $operation, $key, $payload);
            throw $exception;
        } catch (\Throwable $exception) {
            $this->idempotency->abandon($context, $operation, $key, $payload);
            throw $exception;
        }
    }
}
