<?php

namespace App\Modules\Partner\Services;

use App\Models\Partner;
use App\Models\PartnerApiClient;
use App\Models\PartnerStockAllocationItem;
use App\Models\PartnerTenant;
use App\Models\SyncInbox;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Str;

class PartnerSyncService
{
    private const DEFAULT_ALLOCATION_LIMIT = 5000;
    private const MAX_ALLOCATION_LIMIT = 20000;
    private const MAX_EVENT_BATCH_SIZE = 1000;

    /**
     * @return array{ok: bool, error?: string}
     */
    public function authenticate(?string $token, string $partnerId, string $tenantId): array
    {
        if ($token === null || $token === '') {
            return ['ok' => false, 'error' => 'authentication_required'];
        }

        $partner = Partner::query()->where('id', $partnerId)->where('status', 'active')->first();
        $tenant = PartnerTenant::query()
            ->where('id', $tenantId)
            ->where('partner_id', $partnerId)
            ->whereIn('status', ['active', 'maintenance'])
            ->first();

        if ($partner === null || $tenant === null) {
            return ['ok' => false, 'error' => 'permission_denied'];
        }

        $client = PartnerApiClient::query()
            ->where('partner_id', $partnerId)
            ->where('secret_hash', hash('sha256', $token))
            ->where('status', 'active')
            ->whereNull('revoked_at')
            ->first();

        if ($client === null) {
            return ['ok' => false, 'error' => 'authentication_required'];
        }

        PartnerApiClient::query()->where('id', $client->id)->update([
            'last_used_at' => now(),
            'updated_at' => now(),
        ]);

        return ['ok' => true];
    }

    /**
     * @param array<string, mixed> $queryParams
     * @return array{data: array<int, array<string, mixed>>, meta: array<string, mixed>}
     */
    public function pullAllocations(string $partnerId, string $tenantId, array $queryParams): array
    {
        $limit = $this->allocationLimit($queryParams['limit'] ?? null);
        $query = PartnerStockAllocationItem::query()
            ->join('stock_items', 'stock_items.id', '=', 'partner_stock_allocation_items.stock_item_id')
            ->where('partner_stock_allocation_items.partner_id', $partnerId)
            ->where('partner_stock_allocation_items.tenant_id', $tenantId)
            ->where('partner_stock_allocation_items.status', 'allocated')
            ->select([
                'partner_stock_allocation_items.stock_item_id',
                'partner_stock_allocation_items.game_id',
                'stock_items.full_number',
                'stock_items.front3',
                'stock_items.back3',
                'stock_items.back2',
            ])
            ->orderBy('partner_stock_allocation_items.stock_item_id')
            ->limit($limit + 1);

        if (($queryParams['cursor'] ?? null) !== null && trim((string) $queryParams['cursor']) !== '') {
            $query->where('partner_stock_allocation_items.stock_item_id', '>', trim((string) $queryParams['cursor']));
        }

        $rows = $query->get()->all();
        $hasMore = count($rows) > $limit;
        $rows = array_slice($rows, 0, $limit);

        return [
            'data' => array_map(fn (object $row): array => [
                'stock_item_id' => (string) $row->stock_item_id,
                'game_id' => (string) $row->game_id,
                'full_number' => (string) $row->full_number,
                'front3' => $row->front3,
                'back3' => $row->back3,
                'back2' => $row->back2,
            ], $rows),
            'meta' => [
                'next_cursor' => $hasMore && $rows !== [] ? (string) end($rows)->stock_item_id : null,
                'has_more' => $hasMore,
            ],
        ];
    }

    /**
     * @param array<string, mixed> $payload
     * @return array<string, array<int, string>>
     */
    public function validateEventBatch(string $partnerId, string $tenantId, array $payload): array
    {
        $events = $payload['events'] ?? null;
        $errors = [];

        if (! is_array($events) || $events === []) {
            return ['events' => ['The events field must contain at least one event.']];
        }

        if (count($events) > self::MAX_EVENT_BATCH_SIZE) {
            $errors['events'][] = 'The events field must contain 1000 events or fewer.';
        }

        foreach (array_values($events) as $index => $event) {
            if (! is_array($event)) {
                $errors["events.$index"][] = 'The event row is invalid.';
                continue;
            }

            foreach (['event_id', 'event_type', 'occurred_at', 'producer', 'idempotency_key', 'correlation_id'] as $field) {
                if (trim((string) ($event[$field] ?? '')) === '') {
                    $errors["events.$index.$field"][] = 'The '.$field.' field is required.';
                }
            }

            if ((int) ($event['event_version'] ?? 0) < 1) {
                $errors["events.$index.event_version"][] = 'The event_version field must be at least 1.';
            }

            if (! is_array($event['payload'] ?? null)) {
                $errors["events.$index.payload"][] = 'The payload field must be an object.';
            }

            if (($event['tenant_id'] ?? null) !== null && (string) $event['tenant_id'] !== $tenantId) {
                $errors["events.$index.tenant_id"][] = 'The tenant_id field must match X-Tenant-Id.';
            }

            if (($event['partner_id'] ?? null) !== null && (string) $event['partner_id'] !== $partnerId) {
                $errors["events.$index.partner_id"][] = 'The partner_id field must match X-Partner-Id.';
            }
        }

        return $errors;
    }

    /**
     * @param array<int, array<string, mixed>> $events
     * @return array{accepted_count: int, duplicate_count: int}
     */
    public function acceptEvents(string $partnerId, string $tenantId, array $events): array
    {
        return DB::transaction(function () use ($partnerId, $tenantId, $events): array {
            $accepted = 0;
            $duplicates = 0;
            $now = now();

            foreach ($events as $event) {
                $eventId = trim((string) $event['event_id']);

                if (SyncInbox::query()->where('event_id', $eventId)->exists()) {
                    $duplicates++;
                    continue;
                }

                $inserted = SyncInbox::query()->insertOrIgnore([[
                    'id' => 'inb_'.Str::ulid()->toBase32(),
                    'event_id' => $eventId,
                    'event_type' => trim((string) $event['event_type']),
                    'event_version' => (int) $event['event_version'],
                    'consumer' => 'central_partner_sync',
                    'tenant_id' => $event['tenant_id'] ?? $tenantId,
                    'partner_id' => $event['partner_id'] ?? $partnerId,
                    'game_id' => $event['game_id'] ?? null,
                    'idempotency_key' => trim((string) $event['idempotency_key']),
                    'payload_hash' => $this->hashPayload($event['payload'] ?? []),
                    'status' => 'pending',
                    'processed_at' => null,
                    'last_error' => null,
                    'created_at' => $now,
                    'updated_at' => $now,
                ]]);

                if ($inserted === 1) {
                    $accepted++;
                } else {
                    $duplicates++;
                }
            }

            return [
                'accepted_count' => $accepted,
                'duplicate_count' => $duplicates,
            ];
        });
    }

    private function allocationLimit(mixed $value): int
    {
        if ($value === null || $value === '') {
            return self::DEFAULT_ALLOCATION_LIMIT;
        }

        return max(1, min(self::MAX_ALLOCATION_LIMIT, (int) $value));
    }

    /**
     * @param array<string, mixed> $payload
     */
    private function hashPayload(array $payload): string
    {
        return hash('sha256', json_encode($payload, JSON_THROW_ON_ERROR));
    }
}
