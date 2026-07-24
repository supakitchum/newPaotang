<?php

namespace App\Services;

use App\Auth\SupportActorContext;
use App\Models\SupportMessage;
use App\Models\SupportRating;
use App\Models\SupportTicket;
use Illuminate\Http\UploadedFile;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Str;
use RuntimeException;

class SupportTicketService
{
    public function __construct(
        private readonly SupportAttachmentService $attachments,
        private readonly SupportBroadcaster $broadcaster,
        private readonly SupportQueueService $queue,
    ) {
    }

    /**
     * @param array<string, mixed> $payload
     * @param array<int, UploadedFile> $files
     */
    public function create(
        SupportActorContext $context,
        array $payload,
        array $files,
    ): SupportTicket {
        $active = SupportTicket::query()
            ->where('tenant_id', $context->tenantId())
            ->where('customer_actor_id', $context->actor->id)
            ->whereNotNull('active_slot')
            ->first();
        if ($active !== null) {
            return $active;
        }

        $ticket = DB::transaction(function () use ($context, $payload, $files): SupportTicket {
            $ticket = SupportTicket::query()->create([
                'id' => 'stk_'.Str::ulid()->toBase32(),
                'public_no' => $this->nextPublicNumber($context->tenantId()),
                'tenant_id' => $context->tenantId(),
                'customer_actor_id' => $context->actor->id,
                'category_id' => $payload['category_id'] ?? null,
                'subject' => trim((string) $payload['subject']),
                'status' => 'queued',
                'priority' => 0,
                'active_slot' => 1,
                'referenced_ticket_id' => $payload['referenced_ticket_id'] ?? null,
                'latest_sequence' => 0,
                'queued_at' => now(),
            ]);
            $this->appendMessage($ticket, $context, trim((string) $payload['message']), $files);
            $queuePosition = $this->queue->position($ticket) ?? 1;
            $this->appendSystemMessage(
                $ticket,
                $this->ticketCreatedMessage($ticket, $context, $queuePosition),
            );

            return $ticket->fresh();
        });
        $ticket->wasRecentlyCreated = true;

        $this->broadcaster->ticketChanged($ticket, 'support.ticket.created');

        return $ticket;
    }

    /**
     * @param array<int, UploadedFile> $files
     */
    public function sendMessage(
        SupportTicket $ticket,
        SupportActorContext $context,
        string $body,
        array $files,
    ): SupportMessage {
        if ($ticket->status === 'closed') {
            throw new RuntimeException('ticket_closed');
        }
        if ($context->isAdmin() && $ticket->assigned_admin_actor_id !== $context->actor->id && ! $context->hasPermission('support_ticket.view_all')) {
            throw new RuntimeException('permission_denied');
        }

        $message = DB::transaction(function () use ($ticket, $context, $body, $files): SupportMessage {
            $locked = SupportTicket::query()->whereKey($ticket->id)->lockForUpdate()->firstOrFail();
            if ($locked->status === 'closed') {
                throw new RuntimeException('ticket_closed');
            }
            if (
                $context->isCustomer()
                && ($locked->status === 'queued' || $locked->assigned_admin_actor_id === null)
            ) {
                throw new RuntimeException('ticket_waiting_for_agent');
            }
            $message = $this->appendMessage($locked, $context, trim($body), $files);
            if ($context->isAdmin()) {
                $locked->status = 'in_progress';
                $locked->first_response_at ??= now();
            } elseif (in_array($locked->status, ['assigned', 'waiting_customer'], true)) {
                $locked->status = 'in_progress';
                $locked->waiting_customer_at = null;
            }
            $locked->save();

            return $message;
        });
        $fresh = $ticket->fresh();
        $this->broadcaster->ticketChanged($fresh, 'support.message.created', $context->isAdmin() ? $context->actor : null);
        if ($context->isAdmin()) {
            $this->broadcaster->notification($fresh, 'support.message.created', [
                'message_id' => $message->id,
                'message' => $message->body === null
                    ? [
                        'th-TH' => 'เจ้าหน้าที่ส่งรูปภาพถึงคุณ',
                        'en-US' => 'An agent sent you an image.',
                    ]
                    : Str::limit($message->body, 120),
            ]);
        }

        return $message;
    }

    public function markRead(SupportTicket $ticket, SupportActorContext $context, int $sequence): int
    {
        $read = min(max(0, $sequence), (int) $ticket->latest_sequence);
        $timestamp = now();
        $receipt = DB::selectOne(
            <<<'SQL'
                INSERT INTO support_read_receipts (
                    ticket_id,
                    actor_id,
                    last_read_sequence,
                    read_at,
                    created_at,
                    updated_at
                ) VALUES (?, ?, ?, ?, ?, ?)
                ON CONFLICT (ticket_id, actor_id) DO UPDATE SET
                    last_read_sequence = GREATEST(
                        support_read_receipts.last_read_sequence,
                        EXCLUDED.last_read_sequence
                    ),
                    read_at = CASE
                        WHEN EXCLUDED.last_read_sequence >= support_read_receipts.last_read_sequence
                            THEN EXCLUDED.read_at
                        ELSE support_read_receipts.read_at
                    END,
                    updated_at = EXCLUDED.updated_at
                RETURNING last_read_sequence
                SQL,
            [
                $ticket->id,
                $context->actor->id,
                $read,
                $timestamp,
                $timestamp,
                $timestamp,
            ],
        );

        return (int) ($receipt?->last_read_sequence ?? $read);
    }

    public function markWaitingCustomer(SupportTicket $ticket, SupportActorContext $context): SupportTicket
    {
        if (! $context->isAdmin() || ($ticket->assigned_admin_actor_id !== $context->actor->id && ! $context->hasPermission('support_ticket.view_all'))) {
            throw new RuntimeException('permission_denied');
        }
        if ($ticket->status === 'closed') {
            throw new RuntimeException('ticket_closed');
        }
        $ticket->fill(['status' => 'waiting_customer', 'waiting_customer_at' => now()])->save();
        $this->broadcaster->ticketChanged($ticket, 'support.ticket.waiting_customer', $context->actor);
        $this->broadcaster->notification($ticket, 'support.ticket.waiting_customer', [
        ]);

        return $ticket->fresh();
    }

    public function close(
        SupportTicket $ticket,
        SupportActorContext $context,
        ?string $reason,
    ): SupportTicket {
        if ($ticket->status === 'closed') {
            return $ticket;
        }
        if ($context->isAdmin() && $ticket->assigned_admin_actor_id !== $context->actor->id && ! $context->hasPermission('support_ticket.view_all')) {
            throw new RuntimeException('permission_denied');
        }

        $closed = DB::transaction(function () use ($ticket, $context, $reason): SupportTicket {
            $locked = SupportTicket::query()->whereKey($ticket->id)->lockForUpdate()->firstOrFail();
            if ($locked->status === 'closed') {
                return $locked;
            }
            $locked->fill([
                'status' => 'closed',
                'active_slot' => null,
                'closed_by_type' => $context->actorType(),
                'closed_by_actor_id' => $context->actor->id,
                'close_reason' => $reason,
                'closed_at' => now(),
            ])->save();
            $this->appendSystemMessage($locked, $context->isCustomer()
                ? 'ลูกค้าปิดรายการแล้ว'
                : 'เจ้าหน้าที่ปิดรายการแล้ว');

            return $locked->fresh();
        });
        $this->broadcaster->ticketChanged($closed, 'support.ticket.closed', $context->isAdmin() ? $context->actor : null);
        if ($context->isAdmin()) {
            $this->broadcaster->notification($closed, 'support.ticket.closed', [
            ]);
        }

        return $closed;
    }

    public function rate(
        SupportTicket $ticket,
        SupportActorContext $context,
        int $stars,
        ?string $comment,
    ): SupportRating {
        if ($ticket->status !== 'closed') {
            throw new RuntimeException('ticket_not_closed');
        }

        return SupportRating::query()->firstOrCreate(
            ['ticket_id' => $ticket->id],
            [
                'id' => 'srt_'.Str::ulid()->toBase32(),
                'tenant_id' => $ticket->tenant_id,
                'customer_actor_id' => $context->actor->id,
                'stars' => $stars,
                'comment' => $comment,
            ],
        );
    }

    /**
     * @param array<int, UploadedFile> $files
     */
    private function appendMessage(
        SupportTicket $ticket,
        SupportActorContext $context,
        string $body,
        array $files,
    ): SupportMessage {
        $ticket->latest_sequence = ((int) $ticket->latest_sequence) + 1;
        $ticket->last_message_preview = Str::limit($body !== '' ? $body : 'รูปภาพ', 240);
        $ticket->last_message_at = now();
        $ticket->save();
        $message = SupportMessage::query()->create([
            'id' => 'smsg_'.Str::ulid()->toBase32(),
            'tenant_id' => $ticket->tenant_id,
            'ticket_id' => $ticket->id,
            'sequence' => $ticket->latest_sequence,
            'sender_type' => $context->actorType(),
            'sender_actor_id' => $context->actor->id,
            'body' => $body !== '' ? $body : null,
            'message_type' => $files === [] ? 'text' : ($body === '' ? 'image' : 'mixed'),
        ]);
        $settings = DB::table('support_settings')->where('tenant_id', $ticket->tenant_id)->first();
        $this->attachments->store(
            $ticket,
            $message,
            $files,
            max(1, (int) ($settings->max_attachments_per_message ?? config('support.attachments.max_files', 4))),
            max(1024, (int) ($settings->max_attachment_bytes ?? config('support.attachments.max_bytes', 8388608))),
        );

        return $message;
    }

    private function appendSystemMessage(SupportTicket $ticket, string $body): void
    {
        $ticket->latest_sequence = ((int) $ticket->latest_sequence) + 1;
        $ticket->last_message_preview = $body;
        $ticket->last_message_at = now();
        $ticket->save();
        SupportMessage::query()->create([
            'id' => 'smsg_'.Str::ulid()->toBase32(),
            'tenant_id' => $ticket->tenant_id,
            'ticket_id' => $ticket->id,
            'sequence' => $ticket->latest_sequence,
            'sender_type' => 'system',
            'body' => $body,
            'message_type' => 'system',
        ]);
    }

    private function ticketCreatedMessage(
        SupportTicket $ticket,
        SupportActorContext $context,
        int $queuePosition,
    ): string {
        $content = DB::table('support_settings')
            ->where('tenant_id', $ticket->tenant_id)
            ->value('content_json');
        $runtime = is_string($content) ? json_decode($content, true) : $content;
        $override = is_array($runtime)
            ? data_get($runtime, 'messages.ticket_created')
            : null;
        $defaults = config('support.message_defaults.ticket_created', []);
        $locale = trim((string) ($context->claims['locale'] ?? 'th-TH')) ?: 'th-TH';
        $template = $this->localizedTemplate($override, $defaults, $locale);

        return str_replace('{queue_position}', (string) $queuePosition, $template);
    }

    private function localizedTemplate(mixed $override, mixed $defaults, string $locale): string
    {
        if (is_string($override) && trim($override) !== '') {
            return trim($override);
        }

        $content = is_array($override) && $override !== []
            ? $override
            : (is_array($defaults) ? $defaults : []);
        $fallbacks = is_array($defaults) ? $defaults : [];
        $normalized = strtolower(str_replace('_', '-', $locale));
        $language = explode('-', $normalized)[0];
        foreach ([$locale, $normalized, $language, 'th-TH', 'th', 'en-US', 'en'] as $key) {
            $candidate = $content[$key] ?? $fallbacks[$key] ?? null;
            if (is_string($candidate) && trim($candidate) !== '') {
                return trim($candidate);
            }
        }

        return 'Your support request has been received. Queue position: {queue_position}.';
    }

    private function nextPublicNumber(string $tenantId): string
    {
        do {
            $number = 'SUP-'.now()->format('ymd').'-'.strtoupper(Str::random(6));
        } while (SupportTicket::query()->where('tenant_id', $tenantId)->where('public_no', $number)->exists());

        return $number;
    }
}
