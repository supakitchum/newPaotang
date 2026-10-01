<?php

namespace App\Http\Controllers;

use App\Auth\SupportActorContext;
use App\Models\SupportCategory;
use App\Models\SupportFaq;
use App\Models\SupportMessage;
use App\Models\SupportTicket;
use App\Services\SupportAuditService;
use App\Services\SupportIdempotencyService;
use App\Services\SupportPresenter;
use App\Services\SupportTicketService;
use Illuminate\Database\QueryException;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Routing\Controller;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Str;
use Illuminate\Validation\Rule;
use RuntimeException;

class CustomerSupportController extends Controller
{
    public function __construct(
        private readonly SupportPresenter $presenter,
        private readonly SupportTicketService $tickets,
        private readonly SupportIdempotencyService $idempotency,
        private readonly SupportAuditService $audit,
    ) {
    }

    public function bootstrap(Request $request): JsonResponse
    {
        $context = $this->context($request);
        $locale = $this->locale($request);
        $settings = DB::table('support_settings')->where('tenant_id', $context->tenantId())->first();
        $categories = SupportCategory::query()
            ->where('tenant_id', $context->tenantId())
            ->where('status', 'active')
            ->orderBy('sort_order')
            ->orderBy('id')
            ->get()
            ->map(fn (SupportCategory $category): array => $this->presenter->category($category, $locale))
            ->all();
        $active = $this->customerTickets($context)
            ->whereNotNull('active_slot')
            ->orderByDesc('updated_at')
            ->first();
        $historyCount = $this->customerTickets($context)->where('status', 'closed')->count();

        return response()->json([
            'enabled' => (bool) ($settings->enabled ?? true),
            'categories' => $categories,
            'active_ticket' => $active === null ? null : $this->presenter->ticket($active, $context, true),
            'history_count' => $historyCount,
            'unread_count' => $this->unreadCountFor($context),
            'limits' => [
                'subject_characters' => 120,
                'message_characters' => 4000,
                'rating_comment_characters' => 500,
                'attachments_per_message' => (int) ($settings->max_attachments_per_message ?? 4),
                'attachment_bytes' => (int) ($settings->max_attachment_bytes ?? 8388608),
            ],
            'runtime_content' => is_string($settings->content_json ?? null)
                ? json_decode((string) $settings->content_json, true)
                : ($settings->content_json ?? null),
        ]);
    }

    public function faqs(Request $request): JsonResponse
    {
        $context = $this->context($request);
        $locale = $this->locale($request);
        $search = trim((string) $request->query('q', ''));
        $categoryId = trim((string) $request->query('category_id', ''));
        $query = SupportFaq::query()
            ->where('tenant_id', $context->tenantId())
            ->where('status', 'published');
        if ($categoryId !== '') {
            $query->where('category_id', $categoryId);
        }
        if ($search !== '') {
            $needle = '%'.str_replace(['%', '_'], ['\%', '\_'], mb_strtolower($search)).'%';
            $query->where(function ($nested) use ($needle): void {
                $nested->whereRaw('lower(question_json::text) like ?', [$needle])
                    ->orWhereRaw('lower(answer_json::text) like ?', [$needle])
                    ->orWhereRaw('lower(coalesce(keywords_json::text, \'\')) like ?', [$needle]);
            });
        }
        $items = $query->orderBy('sort_order')->orderByDesc('published_at')->limit(100)->get();

        return response()->json([
            'data' => $items->map(fn (SupportFaq $faq): array => $this->presenter->faq($faq, $locale))->all(),
        ]);
    }

    public function faqFeedback(Request $request, string $faq): JsonResponse
    {
        $context = $this->context($request);
        $resource = SupportFaq::query()
            ->where('tenant_id', $context->tenantId())
            ->where('status', 'published')
            ->whereKey($faq)
            ->firstOrFail();
        $payload = $request->validate(['helpful' => ['required', 'boolean']]);
        $key = $this->idempotencyKey($request);
        $helpful = (bool) $payload['helpful'];

        return $this->idempotent($context, 'customer.faq.feedback', $key, [
            'faq_id' => (string) $resource->id,
            'helpful' => $helpful,
        ], function () use ($context, $resource, $helpful): array {
            DB::table('support_faq_feedback')->upsert([[
                'id' => 'sff_'.Str::ulid()->toBase32(),
                'tenant_id' => $context->tenantId(),
                'faq_id' => $resource->id,
                'customer_actor_id' => $context->actor->id,
                'helpful' => $helpful,
                'created_at' => now(),
                'updated_at' => now(),
            ]], ['tenant_id', 'faq_id', 'customer_actor_id'], ['helpful', 'updated_at']);

            return [200, ['faq_id' => (string) $resource->id, 'helpful' => $helpful]];
        });
    }

    public function unreadCount(Request $request): JsonResponse
    {
        $context = $this->context($request);

        return response()->json(['unread_count' => $this->unreadCountFor($context)]);
    }

    public function index(Request $request): JsonResponse
    {
        $context = $this->context($request);
        $status = trim((string) $request->query('status', 'active'));
        $limit = min(50, max(1, (int) $request->query('limit', 20)));
        $cursor = trim((string) $request->query('cursor', ''));
        $query = $this->customerTickets($context);
        $status === 'closed'
            ? $query->where('status', 'closed')
            : $query->where('status', '!=', 'closed');
        if ($cursor !== '') {
            $query->where('id', '<', $cursor);
        }
        $items = $query->orderByDesc('id')->limit($limit + 1)->get();
        $hasMore = $items->count() > $limit;
        $page = $items->take($limit);

        return response()->json([
            'data' => $page->map(fn (SupportTicket $ticket): array => $this->presenter->ticket($ticket, $context))->all(),
            'next_cursor' => $hasMore ? (string) $page->last()?->id : null,
        ]);
    }

    public function store(Request $request): JsonResponse
    {
        $context = $this->context($request);
        [$maxAttachments, $maxAttachmentKilobytes] = $this->attachmentLimits($context);
        $payload = $request->validate([
            'category_id' => [
                'nullable',
                'string',
                Rule::exists('support_categories', 'id')->where(
                    fn ($query) => $query->where('tenant_id', $context->tenantId())->where('status', 'active'),
                ),
            ],
            'subject' => ['required', 'string', 'max:120'],
            'message' => ['required', 'string', 'max:4000'],
            'referenced_ticket_id' => [
                'nullable',
                'string',
                Rule::exists('support_tickets', 'id')->where(
                    fn ($query) => $query->where('tenant_id', $context->tenantId())->where('customer_actor_id', $context->actor->id),
                ),
            ],
            'attachments' => ['sometimes', 'array', 'max:'.$maxAttachments],
            'attachments.*' => [
                'file',
                'mimes:jpeg,jpg,png,webp',
                'max:'.$maxAttachmentKilobytes,
            ],
        ]);
        $files = $request->file('attachments', []);
        $idempotencyKey = $this->idempotencyKey($request);
        $hashPayload = [
            'category_id' => $payload['category_id'] ?? null,
            'subject' => trim((string) $payload['subject']),
            'message' => trim((string) $payload['message']),
            'referenced_ticket_id' => $payload['referenced_ticket_id'] ?? null,
            'attachments' => $this->attachmentFingerprints(is_array($files) ? $files : []),
        ];

        return $this->idempotent($context, 'customer.ticket.create', $idempotencyKey, $hashPayload, function () use ($context, $payload, $files): array {
            try {
                $ticket = $this->tickets->create($context, $payload, is_array($files) ? $files : []);
            } catch (QueryException $exception) {
                if (! str_contains(strtolower($exception->getMessage()), 'unique')) {
                    throw $exception;
                }
                $ticket = $this->customerTickets($context)->whereNotNull('active_slot')->firstOrFail();
            }

            return [201, [
                'ticket' => $this->presenter->ticket($ticket, $context, true),
                'existing' => $ticket->wasRecentlyCreated === false,
            ]];
        });
    }

    public function show(Request $request, string $ticket): JsonResponse
    {
        $context = $this->context($request);
        $resource = $this->findCustomerTicket($context, $ticket);

        return response()->json(['ticket' => $this->presenter->ticket($resource, $context, true)]);
    }

    public function messages(Request $request, string $ticket): JsonResponse
    {
        $context = $this->context($request);
        $resource = $this->findCustomerTicket($context, $ticket);
        $before = max(0, (int) $request->query('before_sequence', 0));
        $limit = min(100, max(1, (int) $request->query('limit', 40)));
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
        $context = $this->context($request);
        $resource = $this->findCustomerTicket($context, $ticket);
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
        $hashPayload = [
            'ticket_id' => $resource->id,
            'body' => $body,
            'attachments' => $this->attachmentFingerprints(is_array($files) ? $files : []),
        ];

        return $this->idempotent($context, 'customer.message.create', $key, $hashPayload, function () use ($resource, $context, $body, $files): array {
            $message = $this->tickets->sendMessage($resource, $context, $body, is_array($files) ? $files : []);

            return [201, ['message' => $this->presenter->message($message, $context)]];
        });
    }

    public function markRead(Request $request, string $ticket): JsonResponse
    {
        $context = $this->context($request);
        $resource = $this->findCustomerTicket($context, $ticket);
        $payload = $request->validate(['sequence' => ['required', 'integer', 'min:0']]);
        $key = $this->idempotencyKey($request);

        return $this->idempotent($context, 'customer.ticket.read', $key, [
            'ticket_id' => $resource->id,
            'sequence' => (int) $payload['sequence'],
        ], function () use ($resource, $context, $payload): array {
            $read = $this->tickets->markRead($resource, $context, (int) $payload['sequence']);

            return [200, [
                'last_read_sequence' => $read,
                'unread_count' => SupportMessage::query()
                    ->where('ticket_id', $resource->id)
                    ->where('sequence', '>', $read)
                    ->where('sender_type', '!=', 'customer')
                    ->count(),
            ]];
        });
    }

    public function close(Request $request, string $ticket): JsonResponse
    {
        $context = $this->context($request);
        $resource = $this->findCustomerTicket($context, $ticket);
        $payload = $request->validate(['reason' => ['nullable', 'string', 'max:500']]);
        $key = $this->idempotencyKey($request);

        return $this->idempotent($context, 'customer.ticket.close', $key, [
            'ticket_id' => $resource->id,
            'reason' => trim((string) ($payload['reason'] ?? '')),
        ], function () use ($resource, $context, $payload): array {
            $wasClosed = $resource->status === 'closed';
            $ticket = $this->tickets->close($resource, $context, trim((string) ($payload['reason'] ?? '')) ?: null);
            if (! $wasClosed) {
                $this->audit->record(
                    $context,
                    'customer.ticket.close',
                    'ticket',
                    (string) $ticket->id,
                );
            }

            return [200, ['ticket' => $this->presenter->ticket($ticket, $context)]];
        });
    }

    public function rate(Request $request, string $ticket): JsonResponse
    {
        $context = $this->context($request);
        $resource = $this->findCustomerTicket($context, $ticket);
        $payload = $request->validate([
            'stars' => ['required', 'integer', 'between:1,5'],
            'comment' => ['nullable', 'string', 'max:500'],
        ]);
        $key = $this->idempotencyKey($request);

        return $this->idempotent($context, 'customer.ticket.rate', $key, [
            'ticket_id' => $resource->id,
            'stars' => (int) $payload['stars'],
            'comment' => trim((string) ($payload['comment'] ?? '')),
        ], function () use ($resource, $context, $payload): array {
            $rating = $this->tickets->rate(
                $resource,
                $context,
                (int) $payload['stars'],
                trim((string) ($payload['comment'] ?? '')) ?: null,
            );
            if ($rating->wasRecentlyCreated) {
                $this->audit->record(
                    $context,
                    'customer.ticket.rate',
                    'ticket',
                    (string) $resource->id,
                    ['stars' => (int) $rating->stars],
                );
            }

            return [201, ['rating' => [
                'stars' => (int) $rating->stars,
                'comment' => $rating->comment,
                'created_at' => $rating->created_at?->toIso8601String(),
            ]]];
        });
    }

    private function context(Request $request): SupportActorContext
    {
        /** @var SupportActorContext $context */
        $context = $request->attributes->get('support_actor');

        return $context;
    }

    private function customerTickets(SupportActorContext $context)
    {
        return SupportTicket::query()
            ->where('tenant_id', $context->tenantId())
            ->where('customer_actor_id', $context->actor->id);
    }

    private function findCustomerTicket(SupportActorContext $context, string $ticket): SupportTicket
    {
        return $this->customerTickets($context)->whereKey($ticket)->firstOrFail();
    }

    private function unreadCountFor(SupportActorContext $context): int
    {
        return SupportMessage::query()
            ->join('support_tickets', 'support_tickets.id', '=', 'support_messages.ticket_id')
            ->leftJoin('support_read_receipts', function ($join) use ($context): void {
                $join->on('support_read_receipts.ticket_id', '=', 'support_messages.ticket_id')
                    ->where('support_read_receipts.actor_id', '=', $context->actor->id);
            })
            ->where('support_tickets.tenant_id', $context->tenantId())
            ->where('support_tickets.customer_actor_id', $context->actor->id)
            ->where('support_messages.sender_type', '!=', 'customer')
            ->whereRaw(
                'support_messages.sequence > coalesce(support_read_receipts.last_read_sequence, 0)',
            )
            ->count();
    }

    private function locale(Request $request): string
    {
        return trim(explode(',', (string) $request->header('Accept-Language', 'th-TH'))[0]) ?: 'th-TH';
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
     * @param array<int, mixed> $files
     * @return array<int, array<string, mixed>>
     */
    private function attachmentFingerprints(array $files): array
    {
        return array_map(static fn ($file): array => [
            'name' => method_exists($file, 'getClientOriginalName') ? $file->getClientOriginalName() : '',
            'size' => method_exists($file, 'getSize') ? $file->getSize() : 0,
            'sha256' => method_exists($file, 'getRealPath') ? hash_file('sha256', $file->getRealPath()) : '',
        ], $files);
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
