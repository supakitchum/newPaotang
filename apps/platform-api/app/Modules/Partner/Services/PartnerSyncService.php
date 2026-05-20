<?php

namespace App\Modules\Partner\Services;

use App\Models\Partner;
use App\Models\PartnerApiClient;
use App\Models\PartnerStockAllocation;
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
        $query = DB::table('stock_partner_distributions')
            ->where('partner_id', $partnerId)
            ->where('tenant_id', $tenantId)
            ->orderBy('id')
            ->limit($limit + 1);

        if (($queryParams['cursor'] ?? null) !== null && trim((string) $queryParams['cursor']) !== '') {
            $query->where('id', '>', trim((string) $queryParams['cursor']));
        }

        $rows = $query->get()->all();
        $hasMore = count($rows) > $limit;
        $rows = array_slice($rows, 0, $limit);
        $allocations = $this->latestVirtualAllocationsForRows($partnerId, $tenantId, $rows);

        return [
            'data' => array_map(fn (object $row): array => $this->virtualAllocationResource($row, $allocations[(string) $row->game_id] ?? null), $rows),
            'meta' => [
                'next_cursor' => $hasMore && $rows !== [] ? (string) end($rows)->id : null,
                'has_more' => $hasMore,
            ],
        ];
    }

    /**
     * @param array<int, object> $distributionRows
     * @return array<string, object>
     */
    private function latestVirtualAllocationsForRows(string $partnerId, string $tenantId, array $distributionRows): array
    {
        $gameIds = array_values(array_unique(array_map(fn (object $row): string => (string) $row->game_id, $distributionRows)));

        if ($gameIds === []) {
            return [];
        }

        $allocations = [];
        $rows = PartnerStockAllocation::query()
            ->where('partner_id', $partnerId)
            ->where('tenant_id', $tenantId)
            ->whereIn('game_id', $gameIds)
            ->whereNotNull('allocation_percent_basis_points')
            ->orderByDesc('created_at')
            ->orderByDesc('id')
            ->get()
            ->all();

        foreach ($rows as $allocation) {
            $gameId = (string) $allocation->game_id;

            if (! array_key_exists($gameId, $allocations)) {
                $allocations[$gameId] = $allocation;
            }
        }

        return $allocations;
    }

    /**
     * @return array<string, mixed>
     */
    private function virtualAllocationResource(object $distribution, ?object $allocation): array
    {
        $gameId = (string) $distribution->game_id;
        $basisPoints = max(0, (int) $distribution->percent_basis_points);
        $generatedSupplyCount = $this->activeVirtualSupplyCount($gameId);
        $targetCount = $allocation === null
            ? (int) floor(($generatedSupplyCount * $basisPoints) / 10000)
            : (int) $allocation->requested_count;
        $usedCount = $this->partnerUsedVirtualCount($gameId, (string) $distribution->partner_id);
        $status = (string) ($allocation->status ?? $distribution->status);
        $remainingCount = in_array($status, ['recalled', 'cancelled', 'inactive', 'archived'], true)
            ? 0
            : max(0, $targetCount - $usedCount - (int) ($allocation->recalled_count ?? 0));

        return [
            'id' => (string) $distribution->id,
            'source' => 'stock_partner_distributions',
            'stock_mode' => 'virtual',
            'allocation_id' => $allocation === null ? null : (string) $allocation->id,
            'partner_id' => (string) $distribution->partner_id,
            'tenant_id' => $distribution->tenant_id === null ? null : (string) $distribution->tenant_id,
            'game_id' => $gameId,
            'status' => $status,
            'allocation_percent' => $this->percentFromBasisPoints($basisPoints),
            'allocation_percent_basis_points' => $basisPoints,
            'generated_supply_count' => $generatedSupplyCount,
            'allocated_count' => $targetCount,
            'remaining_count' => $remainingCount,
            'used_count' => $usedCount,
            'recalled_count' => (int) ($allocation->recalled_count ?? 0),
            'updated_at' => $distribution->updated_at ?? null,
        ];
    }

    private function activeVirtualSupplyCount(string $gameId): int
    {
        $profile = DB::table('stock_supply_profiles')
            ->where('game_id', $gameId)
            ->where('status', 'active')
            ->first();

        if ($profile === null) {
            return 0;
        }

        $layerCount = (int) DB::table('virtual_stock_supply_layers')
            ->where('profile_id', (string) $profile->id)
            ->where('status', 'active')
            ->sum('total_capacity');

        return $layerCount > 0 ? $layerCount : (int) $profile->total_capacity;
    }

    private function partnerUsedVirtualCount(string $gameId, string $partnerId): int
    {
        return (int) DB::table('virtual_stock_counters')
            ->where('game_id', $gameId)
            ->where('scope_type', 'partner')
            ->where('scope_id', $partnerId)
            ->selectRaw('COALESCE(SUM(reserved_count + sold_count), 0) as used_count')
            ->value('used_count');
    }

    private function percentFromBasisPoints(int $basisPoints): float|int
    {
        $value = $basisPoints / 100;

        return fmod($value, 1.0) === 0.0 ? (int) $value : $value;
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
