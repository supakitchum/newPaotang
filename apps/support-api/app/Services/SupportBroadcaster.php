<?php

namespace App\Services;

use App\Events\SupportChanged;
use App\Models\SupportActor;
use App\Models\SupportOutbox;
use App\Models\SupportTicket;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Str;

class SupportBroadcaster
{
    public function ticketChanged(SupportTicket $ticket, string $eventName, ?SupportActor $admin = null): void
    {
        $customerExternalId = (string) SupportActor::query()
            ->whereKey($ticket->customer_actor_id)
            ->value('external_id');
        $channels = [
            'support.tenant.'.$ticket->tenant_id.'.customer.'.$customerExternalId,
            'support.tenant.'.$ticket->tenant_id.'.queue',
            'support.tenant.'.$ticket->tenant_id.'.ticket.'.$ticket->id,
        ];
        if ($admin !== null) {
            $channels[] = 'support.tenant.'.$ticket->tenant_id.'.admin.'.$admin->external_id;
        }

        try {
            SupportChanged::dispatch($eventName, array_values(array_unique($channels)), [
                'ticket_id' => (string) $ticket->id,
                'status' => (string) $ticket->status,
            ]);
        } catch (\Throwable) {
        }
    }

    /**
     * @param array<string, mixed> $payload
     */
    public function notification(SupportTicket $ticket, string $eventKey, array $payload): void
    {
        $customerExternalId = (string) SupportActor::query()
            ->whereKey($ticket->customer_actor_id)
            ->value('external_id');
        $settingsContent = DB::table('support_settings')
            ->where('tenant_id', $ticket->tenant_id)
            ->value('content_json');
        $runtime = is_string($settingsContent)
            ? json_decode($settingsContent, true)
            : $settingsContent;
        $allDefaults = config('support.notification_defaults', []);
        $defaults = is_array($allDefaults)
            ? ($allDefaults[$eventKey] ?? [])
            : [];
        $override = is_array($runtime)
            ? ($runtime['notifications'][$eventKey] ?? [])
            : [];
        $variables = [
            'ticket_no' => (string) $ticket->public_no,
            'message' => $payload['message'] ?? '',
        ];
        $title = $this->localizedContent(
            is_array($override) ? ($override['title'] ?? null) : null,
            is_array($defaults) ? ($defaults['title'] ?? []) : [],
            $variables,
        );
        $body = $this->localizedContent(
            is_array($override) ? ($override['body'] ?? null) : null,
            is_array($defaults) ? ($defaults['body'] ?? []) : [],
            $variables,
        );
        unset($payload['message'], $payload['title'], $payload['body']);
        $dedupeKey = $eventKey.':'.$ticket->id.':'.($payload['message_id'] ?? $ticket->updated_at?->getTimestamp() ?? 0);

        SupportOutbox::query()->firstOrCreate(
            ['dedupe_key' => hash('sha256', $dedupeKey)],
            [
                'id' => 'sob_'.Str::ulid()->toBase32(),
                'tenant_id' => $ticket->tenant_id,
                'event_key' => $eventKey,
                'aggregate_type' => 'support_ticket',
                'aggregate_id' => $ticket->id,
                'payload_json' => [
                    'tenant_id' => (string) $ticket->tenant_id,
                    'customer_id' => $customerExternalId,
                    'ticket_id' => (string) $ticket->id,
                    'ticket_no' => (string) $ticket->public_no,
                    'event_key' => $eventKey,
                    'title' => $title,
                    'body' => $body,
                    ...$payload,
                ],
                'status' => 'pending',
                'attempts' => 0,
                'available_at' => now(),
            ],
        );
    }

    /**
     * @param mixed $override
     * @param mixed $defaults
     * @param array<string, mixed> $variables
     * @return array<string, string>
     */
    private function localizedContent(mixed $override, mixed $defaults, array $variables): array
    {
        $content = is_array($override) && $override !== []
            ? $override
            : (is_array($defaults) ? $defaults : []);
        $fallbacks = is_array($defaults) ? $defaults : [];
        $result = [];
        foreach (array_unique([...array_keys($fallbacks), ...array_keys($content)]) as $locale) {
            $template = trim((string) ($content[$locale] ?? $fallbacks[$locale] ?? ''));
            foreach ($variables as $key => $value) {
                $replacement = is_array($value)
                    ? (string) ($value[$locale] ?? $value['th-TH'] ?? $value['en-US'] ?? '')
                    : (string) $value;
                $template = str_replace('{'.$key.'}', $replacement, $template);
            }
            if ($template !== '') {
                $result[(string) $locale] = $template;
            }
        }

        return $result;
    }
}
