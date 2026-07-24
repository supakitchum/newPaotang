<?php

namespace App\Services;

use App\Auth\SupportActorContext;
use App\Models\SupportActor;
use App\Models\SupportAttachment;
use App\Models\SupportCategory;
use App\Models\SupportFaq;
use App\Models\SupportMessage;
use App\Models\SupportRating;
use App\Models\SupportTicket;
use Illuminate\Support\Facades\DB;

class SupportPresenter
{
    public function __construct(
        private readonly SupportAttachmentService $attachments,
        private readonly SupportQueueService $queue,
    ) {
    }

    /**
     * @return array<string, mixed>
     */
    public function category(SupportCategory $category, string $locale): array
    {
        return [
            'id' => (string) $category->id,
            'code' => (string) $category->code,
            'name' => $this->localized($category->name_json, $locale),
            'icon_key' => $category->icon_key,
            'is_fallback' => (bool) $category->is_fallback,
        ];
    }

    /**
     * @return array<string, mixed>
     */
    public function faq(SupportFaq $faq, string $locale): array
    {
        return [
            'id' => (string) $faq->id,
            'category_id' => $faq->category_id,
            'question' => $this->localized($faq->question_json, $locale),
            'answer' => $this->localized($faq->answer_json, $locale),
        ];
    }

    /**
     * @return array<string, mixed>
     */
    public function ticket(SupportTicket $ticket, SupportActorContext $viewer, bool $withQueue = false): array
    {
        $customer = SupportActor::query()->find($ticket->customer_actor_id);
        $category = $ticket->category_id === null
            ? null
            : SupportCategory::query()->find($ticket->category_id);
        $agent = $ticket->assigned_admin_actor_id === null
            ? null
            : SupportActor::query()->find($ticket->assigned_admin_actor_id);
        $closedBy = $ticket->closed_by_actor_id === null
            ? null
            : SupportActor::query()->find($ticket->closed_by_actor_id);
        $rating = SupportRating::query()->where('ticket_id', $ticket->id)->first();
        $lastRead = (int) DB::table('support_read_receipts')
            ->where('ticket_id', $ticket->id)
            ->where('actor_id', $viewer->actor->id)
            ->value('last_read_sequence');
        $unreadCount = SupportMessage::query()
            ->where('ticket_id', $ticket->id)
            ->where('sequence', '>', $lastRead)
            ->where('sender_type', '!=', $viewer->actorType())
            ->count();
        $queuePosition = $withQueue ? $this->queue->position($ticket) : null;

        return [
            'id' => (string) $ticket->id,
            'public_no' => (string) $ticket->public_no,
            'category_id' => $ticket->category_id,
            'category' => $category === null
                ? null
                : $this->category($category, (string) ($viewer->claims['locale'] ?? 'th-TH')),
            'subject' => (string) $ticket->subject,
            'status' => (string) $ticket->status,
            'priority' => (int) $ticket->priority,
            'last_message_preview' => (string) ($ticket->last_message_preview ?? ''),
            'latest_sequence' => (int) $ticket->latest_sequence,
            'unread_count' => $unreadCount,
            'queue_position' => $queuePosition,
            'opened_at' => $ticket->created_at?->toIso8601String(),
            'queued_at' => $ticket->queued_at?->toIso8601String(),
            'assigned_at' => $ticket->assigned_at?->toIso8601String(),
            'last_message_at' => $ticket->last_message_at?->toIso8601String(),
            'closed_at' => $ticket->closed_at?->toIso8601String(),
            'closed_by_type' => $ticket->closed_by_type,
            'closed_by' => $closedBy === null ? null : [
                'id' => (string) $closedBy->external_id,
                'name' => (string) ($closedBy->display_name ?? ''),
                'actor_type' => (string) $closedBy->actor_type,
            ],
            'close_reason' => $ticket->close_reason,
            'referenced_ticket_id' => $ticket->referenced_ticket_id,
            'customer' => $customer === null ? null : [
                'id' => (string) $customer->external_id,
                'name' => (string) ($customer->display_name ?? ''),
                'member_code' => $customer->member_code,
            ],
            'agent' => $agent === null ? null : [
                'id' => (string) $agent->external_id,
                'name' => (string) ($agent->display_name ?? ''),
            ],
            'rating' => $rating === null ? null : [
                'stars' => (int) $rating->stars,
                'comment' => $rating->comment,
                'created_at' => $rating->created_at?->toIso8601String(),
            ],
        ];
    }

    /**
     * @return array<string, mixed>
     */
    public function message(SupportMessage $message, ?SupportActorContext $viewer = null): array
    {
        $sender = $message->sender_actor_id === null
            ? null
            : SupportActor::query()->find($message->sender_actor_id);
        $attachments = SupportAttachment::query()
            ->where('message_id', $message->id)
            ->orderBy('created_at')
            ->get()
            ->map(fn (SupportAttachment $attachment): array => [
                'id' => (string) $attachment->id,
                'mime_type' => (string) $attachment->mime_type,
                'byte_size' => (int) $attachment->byte_size,
                'width' => $attachment->width,
                'height' => $attachment->height,
                'url' => $this->attachments->temporaryUrl($attachment),
            ])
            ->all();
        $readByCounterpart = null;
        if ($viewer !== null && $message->sender_actor_id === $viewer->actor->id) {
            $counterpartReadSequence = (int) DB::table('support_read_receipts')
                ->join('support_actors', 'support_actors.id', '=', 'support_read_receipts.actor_id')
                ->where('support_read_receipts.ticket_id', $message->ticket_id)
                ->where('support_actors.actor_type', '!=', $viewer->actorType())
                ->max('support_read_receipts.last_read_sequence');
            $readByCounterpart = $counterpartReadSequence >= (int) $message->sequence;
        }

        return [
            'id' => (string) $message->id,
            'sequence' => (int) $message->sequence,
            'sender_type' => (string) $message->sender_type,
            'sender' => $sender === null ? null : [
                'id' => (string) $sender->external_id,
                'name' => (string) ($sender->display_name ?? ''),
            ],
            'body' => (string) ($message->body ?? ''),
            'message_type' => (string) $message->message_type,
            'read_by_counterpart' => $readByCounterpart,
            'attachments' => $attachments,
            'created_at' => $message->created_at?->toIso8601String(),
        ];
    }

    /**
     * @param mixed $value
     */
    private function localized(mixed $value, string $locale): string
    {
        if (! is_array($value)) {
            return is_string($value) ? $value : '';
        }
        $normalized = strtolower(str_replace('_', '-', $locale));
        $language = explode('-', $normalized)[0];
        foreach ([$locale, $normalized, $language, 'th-TH', 'th', 'en-US', 'en'] as $key) {
            $candidate = $value[$key] ?? null;
            if (is_string($candidate) && trim($candidate) !== '') {
                return trim($candidate);
            }
        }

        foreach ($value as $candidate) {
            if (is_string($candidate) && trim($candidate) !== '') {
                return trim($candidate);
            }
        }

        return '';
    }
}
