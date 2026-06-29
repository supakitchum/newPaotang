<?php

namespace App\Modules\Activities\Services;

use App\Models\ActivityClaim;
use App\Models\Customer;
use App\Models\Game;
use App\Models\Order;
use App\Models\PartnerTenant;
use App\Models\PlatformAsset;
use App\Models\RewardPrize;
use App\Models\RewardResult;
use App\Models\TenantActivity;
use App\Models\TenantActivityAward;
use App\Models\TenantActivityCashbackConfig;
use App\Models\TenantActivityEntry;
use App\Models\TenantActivityLuckyConfig;
use App\Models\Ticket;
use App\Models\WinningTicket;
use App\Modules\Auth\Services\CustomerAuthService;
use App\Modules\Activities\Events\ActivityClaimUpdated;
use App\Modules\Commerce\Services\CommerceService;
use App\Modules\LineNotifications\Services\TenantLineNotificationService;
use App\Modules\Rbac\Events\AdminMenuBadgesUpdated;
use App\Modules\StorageConnections\Services\RuntimeStorageService;
use App\Modules\TelegramNotifications\Services\CentralTelegramNotificationService;
use App\Shared\Audit\AuditLogger;
use App\Shared\Auth\AdminSessionContext;
use App\Shared\Auth\CustomerSessionContext;
use App\Support\PublicUrl;
use Illuminate\Http\Request;
use Illuminate\Http\UploadedFile;
use Illuminate\Support\Carbon;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Schema;
use Illuminate\Support\Str;

class TenantActivityService
{
    private const STATUSES = ['draft', 'active', 'inactive', 'archived'];
    private const TYPES = ['lucky_board', 'cashback'];
    private const PREDICTION_TYPES = ['first_prize_last2', 'first_prize_last3', 'last2'];
    private const LUCKY_RULES = ['cumulative_tickets', 'single_order_exact_tickets'];
    private const CASHBACK_TYPES = ['percent', 'fixed'];
    private const CASHBACK_MINIMUM_TYPES = ['tickets', 'amount'];
    private const CLAIM_STATUSES_PENDING = ['submitted', 'under_review', 'approved'];
    private const MAX_IMAGE_BYTES = 8_388_608;
    private const PURPOSE = 'tenant_activity_image';
    private const BUSINESS_TIMEZONE = 'Asia/Bangkok';

    public function __construct(
        private readonly AuditLogger $auditLogger,
        private readonly CustomerAuthService $customerAuth,
        private readonly CommerceService $commerce,
        private readonly TenantLineNotificationService $lineNotifications,
        private readonly RuntimeStorageService $storage,
        private readonly CentralTelegramNotificationService $telegramNotifications,
    ) {
    }

    /**
     * @param array<string, mixed> $queryParams
     * @return array{data: array<int, array<string, mixed>>, meta: array<string, mixed>}
     */
    public function list(string $tenantId, array $queryParams): array
    {
        $limit = $this->limit($queryParams['limit'] ?? null);
        $gameContext = $this->activityGameContext($tenantId, $queryParams, historyMode: false, allowGameSelection: true, activeOnly: false);
        $query = TenantActivity::query()
            ->forTenant($tenantId)
            ->with(['game', 'fullAsset', 'thumbAsset', 'luckyConfig', 'cashbackConfig'])
            ->limit($limit + 1);

        foreach (['status', 'type'] as $field) {
            if (($queryParams[$field] ?? null) !== null && trim((string) $queryParams[$field]) !== '') {
                $query->where($field, trim((string) $queryParams[$field]));
            }
        }

        if ($gameContext['selected_game_id'] !== null) {
            $query->where('game_id', $gameContext['selected_game_id']);
        }

        if (($queryParams['q'] ?? null) !== null && trim((string) $queryParams['q']) !== '') {
            $q = '%'.trim((string) $queryParams['q']).'%';
            $query->where(fn ($builder) => $builder
                ->where('name', 'like', $q)
                ->orWhere('slug', 'like', $q));
        }

        if (($queryParams['cursor'] ?? null) !== null && trim((string) $queryParams['cursor']) !== '') {
            $query->where('id', '<', trim((string) $queryParams['cursor']));
        }

        $sortKey = in_array((string) ($queryParams['sort'] ?? ''), ['name', 'type', 'status', 'sort_order', 'created_at', 'updated_at'], true)
            ? (string) $queryParams['sort']
            : 'created_at';
        $direction = strtolower((string) ($queryParams['direction'] ?? 'desc')) === 'asc' ? 'asc' : 'desc';
        $query->orderBy($sortKey, $direction)->orderBy('id', $direction);

        $rows = $query->get()->all();
        $hasMore = count($rows) > $limit;
        $rows = array_slice($rows, 0, $limit);

        return [
            'data' => array_map(fn (object $row): array => $this->resource($row), $rows),
            'meta' => [
                'next_cursor' => $hasMore && $rows !== [] ? (string) end($rows)->id : null,
                'has_more' => $hasMore,
                'selected_game_id' => $gameContext['selected_game_id'],
                'current_game_id' => $gameContext['current_game_id'],
                'default_game_id' => $gameContext['selected_game_id'],
                'games' => $gameContext['games'],
                'has_history' => $this->hasActivityHistory($gameContext),
            ],
        ];
    }

    /**
     * @return array<string, mixed>|null
     */
    public function find(string $tenantId, string $activityId): ?array
    {
        $row = $this->activityQuery($tenantId)->where('id', $activityId)->first();

        return $row === null ? null : $this->resource($row, true);
    }

    /**
     * @param array<string, mixed> $payload
     * @return array{resource?: array<string, mixed>, error?: string, errors?: array<string, array<int, string>>}
     */
    public function create(string $tenantId, array $payload, AdminSessionContext $actor, Request $request): array
    {
        $tenant = PartnerTenant::whereKey($tenantId)->first();

        if ($tenant === null) {
            return ['error' => 'not_found'];
        }

        $tenant->loadMissing('partner');

        $normalized = $this->basePayload($payload, true);
        $normalized['slug'] = $this->generateActivitySlug($tenant);
        $errors = $this->baseErrors($tenantId, $normalized, true);
        $configPayload = $this->configPayload((string) ($normalized['type'] ?? ''), $payload);
        $errors = array_replace_recursive($errors, $this->configErrors((string) ($normalized['type'] ?? ''), $configPayload));

        if ($errors !== []) {
            return ['error' => 'validation_failed', 'errors' => $errors];
        }

        return DB::transaction(function () use ($tenantId, $normalized, $configPayload, $payload, $actor, $request, $tenant): array {
            $activityId = 'act_'.Str::ulid()->toBase32();
            TenantActivity::query()->create($normalized + [
                'id' => $activityId,
                'tenant_id' => $tenantId,
                'created_at' => now(),
                'updated_at' => now(),
            ]);

            $this->storeConfig($activityId, (string) $normalized['type'], $configPayload);
            $this->audit($actor, $request, 'activity.created', $activityId, $payload, $tenantId, (string) $tenant->partner_id);

            return ['resource' => $this->find($tenantId, $activityId)];
        });
    }

    /**
     * @param array<string, mixed> $payload
     * @return array{resource?: array<string, mixed>, error?: string, errors?: array<string, array<int, string>>}
     */
    public function update(string $tenantId, string $activityId, array $payload, AdminSessionContext $actor, Request $request): array
    {
        $activity = TenantActivity::query()->forTenant($tenantId)->where('id', $activityId)->first();

        if ($activity === null) {
            return ['error' => 'not_found'];
        }

        $tenant = PartnerTenant::whereKey($tenantId)->first();
        $normalized = $this->basePayload($payload, false, $activity);
        $type = (string) ($normalized['type'] ?? $activity->type);
        $errors = $this->baseErrors($tenantId, $normalized, false);
        $configPayload = $this->configPayload($type, $payload);

        if ($configPayload !== []) {
            $errors = array_replace_recursive($errors, $this->configErrors($type, $configPayload));
        }

        if ($this->hasParticipation($activityId)) {
            foreach (['type', 'game_id'] as $field) {
                if (array_key_exists($field, $normalized) && (string) $normalized[$field] !== (string) $activity->{$field}) {
                    $errors[$field][] = 'The '.$field.' field cannot change after customers participate.';
                }
            }
        }

        if ($errors !== []) {
            return ['error' => 'validation_failed', 'errors' => $errors];
        }

        if (
            array_key_exists('slug', $normalized)
            && TenantActivity::query()->forTenant($tenantId)->where('slug', $normalized['slug'])->where('id', '!=', $activityId)->exists()
        ) {
            return ['error' => 'resource_conflict'];
        }

        return DB::transaction(function () use ($tenantId, $activityId, $normalized, $configPayload, $type, $payload, $actor, $request, $tenant): array {
            if ($normalized !== []) {
                TenantActivity::query()->forTenant($tenantId)->where('id', $activityId)->update($normalized + ['updated_at' => now()]);
            }

            if ($configPayload !== []) {
                $this->storeConfig($activityId, $type, $configPayload);
            }

            $this->audit($actor, $request, 'activity.updated', $activityId, $payload, $tenantId, $tenant === null ? null : (string) $tenant->partner_id);

            return ['resource' => $this->find($tenantId, $activityId)];
        });
    }

    /**
     * @param array<string, mixed> $payload
     * @return array{resource?: array<string, mixed>, error?: string, status?: int}
     */
    public function delete(string $tenantId, string $activityId, array $payload, AdminSessionContext $actor, Request $request): array
    {
        $activity = TenantActivity::query()->forTenant($tenantId)->where('id', $activityId)->first();

        if ($activity === null) {
            return ['error' => 'not_found'];
        }

        $tenant = PartnerTenant::whereKey($tenantId)->first();

        return DB::transaction(function () use ($tenantId, $activityId, $payload, $actor, $request, $tenant): array {
            TenantActivity::query()->forTenant($tenantId)->where('id', $activityId)->update([
                'status' => 'archived',
                'updated_at' => now(),
            ]);
            $this->audit($actor, $request, 'activity.archived', $activityId, $payload, $tenantId, $tenant === null ? null : (string) $tenant->partner_id);

            return ['resource' => [], 'status' => 204];
        });
    }

    /**
     * @return array{resource?: array<string, mixed>, error?: string, errors?: array<string, array<int, string>>}
     */
    public function uploadImage(string $tenantId, string $activityId, ?UploadedFile $file, AdminSessionContext $actor, Request $request): array
    {
        $activity = TenantActivity::query()->forTenant($tenantId)->where('id', $activityId)->first();

        if ($activity === null) {
            return ['error' => 'not_found'];
        }

        $errors = $this->imageErrors($file);

        if ($errors !== []) {
            return ['error' => 'validation_failed', 'errors' => $errors];
        }

        $tenant = PartnerTenant::whereKey($tenantId)->first();

        return DB::transaction(function () use ($tenantId, $activityId, $file, $actor, $request, $tenant): array {
            /** @var UploadedFile $file */
            $sourceBytes = file_get_contents($file->getRealPath()) ?: '';
            $variants = [
                'full' => $this->variantPayload($sourceBytes, 1080, 82, $file),
                'thumb' => $this->variantPayload($sourceBytes, 480, 76, $file),
            ];
            $assetIds = [];

            foreach ($variants as $variant => $variantPayload) {
                $assetIds[$variant] = $this->storeVariantAsset($tenantId, $activityId, $variant, $variantPayload, $actor);
            }

            TenantActivity::query()->forTenant($tenantId)->where('id', $activityId)->update([
                'image_full_asset_id' => $assetIds['full'],
                'image_thumb_asset_id' => $assetIds['thumb'],
                'updated_at' => now(),
            ]);
            $this->audit($actor, $request, 'activity.image_uploaded', $activityId, [
                'source_file_name' => $file->getClientOriginalName(),
                'source_size_bytes' => (int) $file->getSize(),
            ], $tenantId, $tenant === null ? null : (string) $tenant->partner_id);

            return ['resource' => $this->find($tenantId, $activityId)];
        });
    }

    /**
     * @param array<string, mixed> $queryParams
     * @return array{data: array<int, array<string, mixed>>, meta: array<string, mixed>, content_source_status: string}
     */
    public function publicList(string $tenantId, array $queryParams = []): array
    {
        $limit = $this->limit($queryParams['limit'] ?? null);
        $gameContext = $this->activityGameContext($tenantId, $queryParams, historyMode: $this->truthy($queryParams['history'] ?? null));
        [$rows, $hasMore, $nextCursor] = $this->activeActivityPage($tenantId, $queryParams, $gameContext, $limit);

        return [
            'data' => array_map(fn (object $row): array => $this->publicResource($row), $rows),
            'meta' => $this->activityListMeta($gameContext, $nextCursor, $hasMore),
            'content_source_status' => $rows === [] ? 'empty' : 'configured',
        ];
    }

    /**
     * @return array<string, mixed>|null
     */
    public function publicFindBySlug(string $tenantId, string $slug): ?array
    {
        $row = $this->activeQuery($tenantId)
            ->where('slug', $this->normalizeSlug($slug))
            ->first();

        return $row === null ? null : $this->publicResource($row, true);
    }

    /**
     * @return array{data: array<int, array<string, mixed>>, meta: array<string, mixed>}
     */
    public function customerActivities(string $tenantId, CustomerSessionContext $customer, array $queryParams): array
    {
        $limit = $this->limit($queryParams['limit'] ?? null);
        $gameContext = $this->activityGameContext($tenantId, $queryParams, historyMode: $this->truthy($queryParams['history'] ?? null));
        [$rows, $hasMore, $nextCursor] = $this->activeActivityPage($tenantId, $queryParams, $gameContext, $limit);

        return [
            'data' => array_map(function (object $row) use ($tenantId, $customer): array {
                $resource = $this->publicResource($row);
                $resource['rights'] = $row->type === 'lucky_board'
                    ? $this->rightsSummary($tenantId, $customer->customerId(), (string) $row->id)
                    : null;
                $resource['cashback_progress'] = $row->type === 'cashback'
                    ? $this->cashbackProgress($tenantId, $customer->customerId(), $row)
                    : null;

                return $resource;
            }, $rows),
            'meta' => $this->activityListMeta($gameContext, $nextCursor, $hasMore),
        ];
    }

    /**
     * @return array<string, mixed>|null
     */
    public function customerActivity(string $tenantId, CustomerSessionContext $customer, string $activityId): ?array
    {
        $row = $this->activeQuery($tenantId)->where('id', $activityId)->first();

        if ($row === null) {
            return null;
        }

        $resource = $this->publicResource($row, true);
        $resource['rights'] = $row->type === 'lucky_board'
            ? $this->rightsSummary($tenantId, $customer->customerId(), (string) $row->id)
            : null;
        $resource['cashback_progress'] = $row->type === 'cashback'
            ? $this->cashbackProgress($tenantId, $customer->customerId(), $row)
            : null;
        $resource['entries'] = $row->type === 'lucky_board'
            ? $this->customerEntries($tenantId, $customer->customerId(), (string) $row->id)
            : [];
        if ((string) $row->type === 'lucky_board') {
            $resource['result_summary'] = $this->luckyBoardResultResource($row, $customer->customerId());
        }

        return $resource;
    }

    /**
     * @return array<string, mixed>|null
     */
    public function customerRights(string $tenantId, CustomerSessionContext $customer, string $activityId): ?array
    {
        return $this->rightsSummary($tenantId, $customer->customerId(), $activityId);
    }

    /**
     * @param array<string, mixed> $payload
     * @return array{resource?: array<string, mixed>, status?: int, error?: string, errors?: array<string, array<int, string>>}
     */
    public function createCustomerEntry(string $tenantId, CustomerSessionContext $customer, string $activityId, array $payload): array
    {
        return DB::transaction(function () use ($tenantId, $customer, $activityId, $payload): array {
            $activity = $this->activeQuery($tenantId)
                ->where('id', $activityId)
                ->where('type', 'lucky_board')
                ->lockForUpdate()
                ->first();

            if ($activity === null) {
                return ['error' => 'not_found'];
            }

            if ($this->luckyBoardEntryClosed($activity)) {
                return ['error' => 'activity_entry_closed'];
            }

            $predictionType = trim((string) ($payload['prediction_type'] ?? ''));
            $selectedNumber = preg_replace('/\D+/', '', trim((string) ($payload['selected_number'] ?? ''))) ?? '';
            $errors = [];

            if (! in_array($predictionType, self::PREDICTION_TYPES, true) || ! $this->predictionEnabled($activity->luckyConfig, $predictionType)) {
                $errors['prediction_type'][] = 'The prediction_type field is invalid.';
            }

            $expectedDigits = $predictionType === 'first_prize_last3' ? 3 : 2;
            if (strlen($selectedNumber) !== $expectedDigits) {
                $errors['selected_number'][] = 'The selected_number field must contain exactly '.$expectedDigits.' digits.';
            }

            if ($errors !== []) {
                return ['error' => 'validation_failed', 'errors' => $errors];
            }

            $rights = $this->rightsSummary($tenantId, $customer->customerId(), (string) $activity->id);

            if (($rights['remaining_count'] ?? 0) < 1) {
                return ['error' => 'resource_conflict'];
            }

            $duplicate = TenantActivityEntry::query()
                ->forTenant($tenantId)
                ->where('activity_id', $activity->id)
                ->where('prediction_type', $predictionType)
                ->where('selected_number', $selectedNumber)
                ->where('status', '!=', 'cancelled')
                ->exists();

            if ($duplicate) {
                return ['error' => 'resource_conflict'];
            }

            Customer::query()
                ->where('tenant_id', $tenantId)
                ->whereKey($customer->customerId())
                ->lockForUpdate()
                ->first();

            $allocation = $this->allocateLuckyRight($tenantId, $customer->customerId(), $activity);

            if ($allocation === null) {
                return ['error' => 'resource_conflict'];
            }

            $config = $activity->luckyConfig;
            $entryId = 'aen_'.Str::ulid()->toBase32();
            TenantActivityEntry::query()->create([
                'id' => $entryId,
                'tenant_id' => $tenantId,
                'activity_id' => (string) $activity->id,
                'game_id' => (string) $activity->game_id,
                'customer_id' => $customer->customerId(),
                'prediction_type' => $predictionType,
                'selected_number' => $selectedNumber,
                'status' => 'submitted',
                'rights_rule' => $config?->eligibility_rule,
                'rights_source_type' => $allocation['source_type'],
                'rights_source_id' => $allocation['source_id'],
                'metadata_json' => $allocation['metadata'],
                'created_at' => now(),
                'updated_at' => now(),
            ]);

            $resource = $this->entryResource(TenantActivityEntry::query()->whereKey($entryId)->first());
            $this->lineNotifications->enqueue($tenantId, $customer->customerId(), 'activity.entry.created', 'tenant_activity_entry', $entryId, $this->lineActivityEntryVariables($tenantId, $activity, $resource));
            $this->telegramNotifications->enqueue($tenantId, 'activity.entry.created', 'tenant_activity_entry', $entryId, $this->telegramActivityEntryVariables($tenantId, $customer->customerId(), $activity, $resource));

            return [
                'resource' => $resource,
                'status' => 201,
            ];
        });
    }

    /**
     * @return array{data: array<int, array<string, mixed>>, meta: array<string, mixed>}
     */
    public function customerAwards(string $tenantId, CustomerSessionContext $customer, array $queryParams): array
    {
        $limit = $this->limit($queryParams['limit'] ?? null);
        $query = TenantActivityAward::query()
            ->forTenant($tenantId)
            ->where('customer_id', $customer->customerId())
            ->with(['activity', 'claim'])
            ->orderByDesc('created_at')
            ->limit($limit + 1);

        if (($queryParams['status'] ?? null) !== null && trim((string) $queryParams['status']) !== '') {
            $query->where('status', trim((string) $queryParams['status']));
        }

        $rows = $query->get()->all();
        $hasMore = count($rows) > $limit;
        $rows = array_slice($rows, 0, $limit);

        return [
            'data' => array_map(fn (object $row): array => $this->awardResource($row, true), $rows),
            'meta' => [
                'next_cursor' => $hasMore && $rows !== [] ? (string) end($rows)->id : null,
                'has_more' => $hasMore,
            ],
        ];
    }

    /**
     * @return array{data: array<int, array<string, mixed>>, meta: array<string, mixed>}
     */
    public function customerClaims(string $tenantId, CustomerSessionContext $customer, array $queryParams): array
    {
        $limit = $this->limit($queryParams['limit'] ?? null);
        $query = ActivityClaim::query()
            ->forTenant($tenantId)
            ->where('customer_id', $customer->customerId())
            ->with(['award', 'activity'])
            ->orderByDesc('created_at')
            ->limit($limit + 1);

        $rows = $query->get()->all();
        $hasMore = count($rows) > $limit;
        $rows = array_slice($rows, 0, $limit);

        return [
            'data' => array_map(fn (object $row): array => $this->claimResource($row), $rows),
            'meta' => [
                'next_cursor' => $hasMore && $rows !== [] ? (string) end($rows)->id : null,
                'has_more' => $hasMore,
            ],
        ];
    }

    /**
     * @return array<string, mixed>|null
     */
    public function customerClaim(string $tenantId, CustomerSessionContext $customer, string $claimId): ?array
    {
        $claim = ActivityClaim::query()
            ->forTenant($tenantId)
            ->where('customer_id', $customer->customerId())
            ->with(['award', 'activity'])
            ->where('id', $claimId)
            ->first();

        return $claim === null ? null : $this->claimResource($claim);
    }

    /**
     * @param array<string, mixed> $payload
     * @return array{resource?: array<string, mixed>, status?: int, error?: string, retry_after_seconds?: int|null}
     */
    public function createCustomerClaim(string $tenantId, CustomerSessionContext $customer, array $payload, Request $request): array
    {
        $pinResult = $this->customerAuth->verifyPinOrAssertionForContext($customer, $payload);

        if (($pinResult['error'] ?? null) !== null) {
            return [
                'error' => $pinResult['error'],
                'retry_after_seconds' => $pinResult['retry_after_seconds'] ?? null,
            ];
        }

        $normalized = [
            'award_id' => trim((string) ($payload['award_id'] ?? $payload['activity_award_id'] ?? '')),
            'payout_method' => trim((string) ($payload['payout_method'] ?? '')),
            'bank_account' => $this->normalizeBankAccount($payload['bank_account'] ?? null),
            'note' => trim((string) ($payload['note'] ?? '')),
        ];
        $idempotencyKey = (string) $request->header('Idempotency-Key');

        return DB::transaction(function () use ($tenantId, $customer, $normalized, $payload, $idempotencyKey): array {
            if (! in_array($normalized['payout_method'], ['wallet_credit', 'bank_transfer'], true) || $normalized['award_id'] === '') {
                return ['error' => 'validation_failed'];
            }

            if ($normalized['payout_method'] === 'bank_transfer' && ! $this->hasUsableBankAccount($normalized['bank_account'])) {
                $normalized['bank_account'] = $this->customerRewardPayoutBankAccount($tenantId, $customer->customerId());
            }

            if ($normalized['payout_method'] === 'bank_transfer' && ! $this->hasUsableBankAccount($normalized['bank_account'])) {
                return ['error' => 'validation_failed'];
            }

            $award = TenantActivityAward::query()
                ->forTenant($tenantId)
                ->where('id', $normalized['award_id'])
                ->where('customer_id', $customer->customerId())
                ->lockForUpdate()
                ->first();

            if ($award === null) {
                return ['error' => 'not_found'];
            }

            if (! in_array((string) $award->status, ['claimable'], true)) {
                return ['error' => 'resource_conflict'];
            }

            if (ActivityClaim::query()->forTenant($tenantId)->where('activity_award_id', $award->id)->whereNotIn('status', ['rejected', 'cancelled'])->exists()) {
                return ['error' => 'resource_conflict'];
            }

            $walletId = $normalized['payout_method'] === 'wallet_credit'
                ? $this->customerAuth->ensurePrimaryWallet($tenantId, $customer->customerId())
                : null;

            if ($normalized['payout_method'] === 'bank_transfer') {
                $this->storeCustomerRewardPayoutBankAccount($tenantId, $customer->customerId(), $normalized['bank_account']);
            }

            $claimId = 'acl_'.Str::ulid()->toBase32();
            $now = now();
            ActivityClaim::query()->create([
                'id' => $claimId,
                'tenant_id' => $tenantId,
                'activity_award_id' => (string) $award->id,
                'activity_id' => (string) $award->activity_id,
                'game_id' => (string) $award->game_id,
                'customer_id' => $customer->customerId(),
                'wallet_id' => $walletId,
                'payout_ledger_id' => null,
                'reference' => 'ACT-'.strtoupper(substr($claimId, -10)),
                'status' => 'submitted',
                'payout_method' => $normalized['payout_method'],
                'claim_amount' => (int) $award->amount,
                'currency' => (string) $award->currency,
                'bank_account_json' => $normalized['bank_account'] === [] ? null : json_encode($normalized['bank_account'], JSON_THROW_ON_ERROR),
                'customer_note' => $payload['note'] ?? null,
                'admin_note' => null,
                'idempotency_key' => $idempotencyKey,
                'payload_hash' => sha1(json_encode($normalized, JSON_THROW_ON_ERROR)),
                'submitted_at' => $now,
                'created_at' => $now,
                'updated_at' => $now,
            ]);
            TenantActivityAward::query()->whereKey((string) $award->id)->update(['status' => 'claimed', 'updated_at' => $now]);
            $this->queueTenantMenuBadgeBroadcast($tenantId, 'activity_claims');
            $this->queueActivityClaimUpdatedBroadcast($tenantId, $claimId);

            return [
                'resource' => $this->claimResource(ActivityClaim::query()->with(['award', 'activity'])->whereKey($claimId)->first()),
                'status' => 201,
            ];
        });
    }

    /**
     * @return array{data: array<int, array<string, mixed>>, meta: array<string, mixed>}
     */
    public function tenantEntries(string $tenantId, string $activityId, array $queryParams): array
    {
        $limit = $this->limit($queryParams['limit'] ?? null);
        $query = TenantActivityEntry::query()
            ->forTenant($tenantId)
            ->where('activity_id', $activityId)
            ->with(['customer', 'award'])
            ->orderByDesc('created_at')
            ->limit($limit + 1);

        if (($queryParams['status'] ?? null) !== null && trim((string) $queryParams['status']) !== '') {
            $query->where('status', trim((string) $queryParams['status']));
        }

        $rows = $query->get()->all();
        $hasMore = count($rows) > $limit;
        $rows = array_slice($rows, 0, $limit);

        return [
            'data' => array_map(fn (object $row): array => $this->entryResource($row), $rows),
            'meta' => [
                'next_cursor' => $hasMore && $rows !== [] ? (string) end($rows)->id : null,
                'has_more' => $hasMore,
            ],
        ];
    }

    /**
     * @return array{data: array<int, array<string, mixed>>, meta: array<string, mixed>}
     */
    public function tenantAwards(string $tenantId, string $activityId, array $queryParams): array
    {
        $limit = $this->limit($queryParams['limit'] ?? null);
        $query = TenantActivityAward::query()
            ->forTenant($tenantId)
            ->where('activity_id', $activityId)
            ->with(['activity', 'entry', 'claim'])
            ->orderByDesc('created_at')
            ->limit($limit + 1);

        if (($queryParams['status'] ?? null) !== null && trim((string) $queryParams['status']) !== '') {
            $query->where('status', trim((string) $queryParams['status']));
        }

        $rows = $query->get()->all();
        $hasMore = count($rows) > $limit;
        $rows = array_slice($rows, 0, $limit);

        return [
            'data' => array_map(fn (object $row): array => $this->awardResource($row, true), $rows),
            'meta' => [
                'next_cursor' => $hasMore && $rows !== [] ? (string) end($rows)->id : null,
                'has_more' => $hasMore,
            ],
        ];
    }

    /**
     * @return array{data: array<int, array<string, mixed>>, meta: array<string, mixed>}
     */
    public function tenantClaims(string $tenantId, array $queryParams): array
    {
        $limit = $this->limit($queryParams['limit'] ?? null);
        $query = ActivityClaim::query()
            ->forTenant($tenantId)
            ->with(['award', 'activity', 'customer'])
            ->limit($limit + 1);

        foreach (['status', 'activity_id', 'game_id'] as $field) {
            if (($queryParams[$field] ?? null) !== null && trim((string) $queryParams[$field]) !== '') {
                $query->where($field, trim((string) $queryParams[$field]));
            }
        }

        if (($queryParams['section'] ?? null) === 'pending') {
            $query->whereIn('status', ['submitted', 'under_review']);
        } elseif (($queryParams['section'] ?? null) === 'history') {
            $query->whereNotIn('status', ['submitted', 'under_review']);
        }

        $sortKey = in_array((string) ($queryParams['sort'] ?? ''), ['reference', 'status', 'payout_method', 'claim_amount', 'submitted_at', 'updated_at', 'created_at'], true)
            ? (string) $queryParams['sort']
            : (($queryParams['section'] ?? null) === 'pending' ? 'submitted_at' : 'updated_at');
        $direction = strtolower((string) ($queryParams['direction'] ?? (($queryParams['section'] ?? null) === 'pending' ? 'asc' : 'desc'))) === 'asc' ? 'asc' : 'desc';

        if (($queryParams['cursor'] ?? null) !== null && trim((string) $queryParams['cursor']) !== '') {
            $query->where('id', $direction === 'asc' ? '>' : '<', trim((string) $queryParams['cursor']));
        }

        $sortExpression = match ($sortKey) {
            'submitted_at' => 'COALESCE(activity_claims.submitted_at, activity_claims.created_at)',
            'updated_at' => 'COALESCE(activity_claims.updated_at, activity_claims.reviewed_at, activity_claims.paid_at, activity_claims.created_at)',
            default => 'activity_claims.'.$sortKey,
        };
        $query->orderByRaw($sortExpression.' '.$direction)->orderBy('id', $direction);

        $rows = $query->get()->all();
        $hasMore = count($rows) > $limit;
        $rows = array_slice($rows, 0, $limit);

        return [
            'data' => array_map(fn (object $row): array => $this->claimResource($row), $rows),
            'meta' => [
                'next_cursor' => $hasMore && $rows !== [] ? (string) end($rows)->id : null,
                'has_more' => $hasMore,
            ],
        ];
    }

    /**
     * @return array<string, mixed>|null
     */
    public function tenantClaim(string $tenantId, string $claimId): ?array
    {
        $claim = ActivityClaim::query()->forTenant($tenantId)->with(['award', 'activity', 'customer'])->where('id', $claimId)->first();

        return $claim === null ? null : $this->claimResource($claim);
    }

    /**
     * @param array<string, mixed> $payload
     * @return array{resource?: array<string, mixed>, status?: int, error?: string}
     */
    public function approveTenantClaim(string $tenantId, AdminSessionContext $actor, string $claimId, array $payload): array
    {
        return DB::transaction(function () use ($tenantId, $actor, $claimId, $payload): array {
            $claim = ActivityClaim::query()->forTenant($tenantId)->where('id', $claimId)->lockForUpdate()->first();

            if ($claim === null) {
                return ['error' => 'not_found'];
            }

            if (! in_array((string) $claim->status, ['submitted', 'under_review', 'approved'], true)) {
                return ['error' => 'resource_conflict'];
            }

            $walletId = $claim->wallet_id;
            $ledger = null;
            $now = now();

            if ((string) $claim->payout_method === 'wallet_credit') {
                $walletId = $walletId ?: $this->customerAuth->ensurePrimaryWallet((string) $claim->tenant_id, (string) $claim->customer_id);
                $ledger = $this->commerce->postLedger(
                    (string) $claim->tenant_id,
                    (string) $walletId,
                    (string) $claim->customer_id,
                    'credit',
                    (int) $claim->claim_amount,
                    'activity_claim',
                    (string) $claim->id,
                    'activity-claim-approve-'.$claim->id,
                    $actor->adminUser['id'],
                    $payload,
                );
            }

            ActivityClaim::query()->whereKey((string) $claim->id)->update([
                'status' => 'paid',
                'wallet_id' => $walletId,
                'payout_ledger_id' => $ledger['id'] ?? $claim->payout_ledger_id,
                'reviewed_by_admin_id' => $actor->adminUser['id'],
                'paid_by_admin_id' => $actor->adminUser['id'],
                'admin_note' => $payload['reason'] ?? $payload['note'] ?? $claim->admin_note,
                'reviewed_at' => $claim->reviewed_at ?? $now,
                'paid_at' => $now,
                'updated_at' => $now,
            ]);
            TenantActivityAward::query()->whereKey((string) $claim->activity_award_id)->update(['status' => 'paid', 'updated_at' => $now]);

            $resource = $this->tenantClaim($tenantId, $claimId);
            $this->lineNotifications->enqueue($tenantId, (string) ($resource['customer']['id'] ?? $claim->customer_id), 'activity_claim.status_updated', 'activity_claim', $claimId, $this->lineActivityClaimVariables($tenantId, $resource ?: [], 'จ่ายเงินกิจกรรมแล้ว'));
            $this->telegramNotifications->enqueue($tenantId, 'activity_claim.status_updated', 'activity_claim', $claimId, $this->telegramActivityClaimVariables($tenantId, $resource ?: [], 'จ่ายเงินกิจกรรมแล้ว', $actor->adminUser));
            $this->queueTenantMenuBadgeBroadcast($tenantId, 'activity_claims');
            $this->queueActivityClaimUpdatedBroadcast($tenantId, $claimId);

            return ['resource' => $resource];
        });
    }

    /**
     * @param array<string, mixed> $payload
     * @return array{resource?: array<string, mixed>, status?: int, error?: string}
     */
    public function rejectTenantClaim(string $tenantId, AdminSessionContext $actor, string $claimId, array $payload): array
    {
        return DB::transaction(function () use ($tenantId, $actor, $claimId, $payload): array {
            $claim = ActivityClaim::query()->forTenant($tenantId)->where('id', $claimId)->lockForUpdate()->first();

            if ($claim === null) {
                return ['error' => 'not_found'];
            }

            if (! in_array((string) $claim->status, ['submitted', 'under_review', 'approved'], true)) {
                return ['error' => 'resource_conflict'];
            }

            $now = now();
            ActivityClaim::query()->whereKey((string) $claim->id)->update([
                'status' => 'rejected',
                'reviewed_by_admin_id' => $actor->adminUser['id'],
                'admin_note' => $payload['reason'] ?? $payload['note'] ?? $claim->admin_note,
                'reviewed_at' => $now,
                'updated_at' => $now,
            ]);
            TenantActivityAward::query()->whereKey((string) $claim->activity_award_id)->update(['status' => 'claimable', 'updated_at' => $now]);

            $resource = $this->tenantClaim($tenantId, $claimId);
            $this->lineNotifications->enqueue($tenantId, (string) ($resource['customer']['id'] ?? $claim->customer_id), 'activity_claim.status_updated', 'activity_claim', $claimId, $this->lineActivityClaimVariables($tenantId, $resource ?: [], 'ไม่อนุมัติ'));
            $this->telegramNotifications->enqueue($tenantId, 'activity_claim.status_updated', 'activity_claim', $claimId, $this->telegramActivityClaimVariables($tenantId, $resource ?: [], 'ไม่อนุมัติ', $actor->adminUser));
            $this->queueTenantMenuBadgeBroadcast($tenantId, 'activity_claims');
            $this->queueActivityClaimUpdatedBroadcast($tenantId, $claimId);

            return ['resource' => $resource];
        });
    }

    /**
     * @param array<string, mixed> $payload
     * @return array{resource?: array<string, mixed>, status?: int, error?: string}
     */
    public function payTenantClaim(string $tenantId, AdminSessionContext $actor, string $claimId, array $payload): array
    {
        return $this->approveTenantClaim($tenantId, $actor, $claimId, $payload);
    }

    /**
     * @return array{lucky_awards: int, cashback_awards: int}
     */
    public function processGame(string $gameId, string $mode = 'all'): array
    {
        $result = RewardResult::query()->where('game_id', $gameId)->where('status', 'published')->first();

        if ($result === null) {
            return ['lucky_awards' => 0, 'cashback_awards' => 0];
        }

        $resultAt = $this->activityResultAtForGame((string) $result->game_id);
        if ($resultAt !== null && now()->lt($resultAt)) {
            return ['lucky_awards' => 0, 'cashback_awards' => 0];
        }

        $luckyAwards = in_array($mode, ['all', 'lucky'], true) ? $this->processLuckyBoardForResult($result) : 0;
        $cashbackAwards = in_array($mode, ['all', 'cashback'], true) ? $this->processCashbackForResult($result) : 0;
        $this->createAutomaticActivityClaimsForGame((string) $result->game_id);
        $this->enqueueTelegramActivityResults($result, $mode);

        return ['lucky_awards' => $luckyAwards, 'cashback_awards' => $cashbackAwards];
    }

    private function enqueueTelegramActivityResults(RewardResult $result, string $mode): void
    {
        $activities = TenantActivity::query()
            ->where('game_id', $result->game_id)
            ->where('status', 'active')
            ->orderBy('sort_order')
            ->orderBy('name')
            ->get()
            ->groupBy('tenant_id');

        $game = Game::query()->whereKey((string) $result->game_id)->first();
        $drawLabel = $game?->draw_at === null
            ? (string) ($game?->name ?? '-')
            : Carbon::parse((string) $game->draw_at)->timezone('Asia/Bangkok')->format('d/m/Y');

        foreach ($activities as $tenantId => $tenantActivities) {
            $lines = [];

            foreach ($tenantActivities as $activity) {
                if ((string) $activity->type === 'lucky_board' && in_array($mode, ['all', 'lucky'], true)) {
                    $count = TenantActivityAward::query()
                        ->where('activity_id', $activity->id)
                        ->where('type', 'lucky_board')
                        ->count();
                    $amount = (int) TenantActivityAward::query()
                        ->where('activity_id', $activity->id)
                        ->where('type', 'lucky_board')
                        ->sum('amount');
                    $lines[] = $count > 0
                        ? '- '.$activity->name.': มีผู้ชนะ '.$count.' คน รวม '.$this->telegramNotifications->baht($amount).' บาท'
                        : '- '.$activity->name.': ไม่มีผู้ชนะ';
                }

                if ((string) $activity->type === 'cashback' && in_array($mode, ['all', 'cashback'], true)) {
                    $count = TenantActivityAward::query()
                        ->where('activity_id', $activity->id)
                        ->where('type', 'cashback')
                        ->count();
                    $amount = (int) TenantActivityAward::query()
                        ->where('activity_id', $activity->id)
                        ->where('type', 'cashback')
                        ->sum('amount');
                    $lines[] = '- '.$activity->name.': มีผู้ได้รับเงินคืน '.$count.' คน รวม '.$this->telegramNotifications->baht($amount).' บาท';
                }
            }

            if ($lines === []) {
                continue;
            }

            $this->telegramNotifications->enqueue((string) $tenantId, 'activity.result.published', 'tenant_activity_result', (string) $result->game_id.':'.(string) $tenantId.':'.$mode, [
                'event' => [
                    'title' => 'ผลกิจกรรมออกแล้ว',
                    'occurred_at' => $this->telegramNotifications->occurredAt(),
                ],
                'tenant' => ['name' => $this->telegramNotifications->tenantName((string) $tenantId)],
                'activity' => [
                    'draw_label' => $drawLabel,
                    'summary' => implode("\n", $lines),
                ],
            ]);
        }
    }

    public function activityResultAtForGame(string $gameId): ?Carbon
    {
        $drawAt = Game::query()->whereKey($gameId)->value('draw_at');

        return $this->activityResultAt($drawAt);
    }

    private function processLuckyBoardForResult(RewardResult $result): int
    {
        $winningNumbers = $this->winningPredictionNumbers((string) $result->id);
        $created = 0;
        $activities = TenantActivity::query()
            ->with(['luckyConfig'])
            ->where('game_id', $result->game_id)
            ->where('type', 'lucky_board')
            ->where('status', 'active')
            ->get()
            ->all();

        foreach ($activities as $activity) {
            $config = $activity->luckyConfig;
            if ($config === null) {
                continue;
            }

            TenantActivityEntry::query()
                ->forTenant((string) $activity->tenant_id)
                ->where('activity_id', $activity->id)
                ->where('status', 'submitted')
                ->orderBy('id')
                ->chunkById(500, function ($entries) use ($activity, $config, $winningNumbers, &$created): void {
                    foreach ($entries as $entry) {
                        $winner = ($winningNumbers[$entry->prediction_type] ?? null) === (string) $entry->selected_number;
                        $now = now();
                        TenantActivityEntry::query()->whereKey((string) $entry->id)->update([
                            'status' => $winner ? 'won' : 'lost',
                            'awarded_at' => $winner ? $now : null,
                            'updated_at' => $now,
                        ]);

                        if (! $winner) {
                            continue;
                        }

                        $amount = $this->luckyPrizeAmount($config, (string) $entry->prediction_type);
                        if ($amount <= 0 || TenantActivityAward::query()->where('entry_id', $entry->id)->exists()) {
                            continue;
                        }

                        TenantActivityAward::query()->create([
                            'id' => 'awa_'.Str::ulid()->toBase32(),
                            'tenant_id' => (string) $activity->tenant_id,
                            'activity_id' => (string) $activity->id,
                            'game_id' => (string) $activity->game_id,
                            'customer_id' => (string) $entry->customer_id,
                            'entry_id' => (string) $entry->id,
                            'type' => 'lucky_board',
                            'prediction_type' => (string) $entry->prediction_type,
                            'amount' => $amount,
                            'currency' => (string) $config->currency,
                            'status' => 'claimable',
                            'calculated_at' => $now,
                            'metadata_json' => ['selected_number' => (string) $entry->selected_number],
                            'created_at' => $now,
                            'updated_at' => $now,
                        ]);
                        $created++;
                    }
                });
        }

        return $created;
    }

    private function processCashbackForResult(RewardResult $result): int
    {
        $created = 0;
        $activities = TenantActivity::query()
            ->with(['cashbackConfig'])
            ->where('game_id', $result->game_id)
            ->where('type', 'cashback')
            ->where('status', 'active')
            ->get()
            ->groupBy('tenant_id');

        foreach ($activities as $tenantId => $tenantActivities) {
            $customers = $this->paidCustomerSummaries((string) $tenantId, (string) $result->game_id);

            foreach ($customers as $customer) {
                $customerId = (string) $customer->customer_id;

                if ($this->customerHasOfficialWinning((string) $tenantId, (string) $result->game_id, $customerId)
                    || $this->customerHasLuckyWinning((string) $tenantId, (string) $result->game_id, $customerId)) {
                    continue;
                }

                if (TenantActivityAward::query()->forTenant((string) $tenantId)->where('game_id', $result->game_id)->where('customer_id', $customerId)->where('type', 'cashback')->exists()) {
                    continue;
                }

                $best = null;
                foreach ($tenantActivities as $activity) {
                    $config = $activity->cashbackConfig;
                    if ($config === null || ! $this->passesCashbackConfig($customer, $config)) {
                        continue;
                    }

                    $amount = $this->cashbackAmount((int) $customer->purchase_amount, $config);
                    if ($amount <= 0) {
                        continue;
                    }

                    $candidate = ['activity' => $activity, 'config' => $config, 'amount' => $amount];
                    if ($best === null || $this->cashbackCandidateIsBetter($candidate, $best)) {
                        $best = $candidate;
                    }
                }

                if ($best === null) {
                    continue;
                }

                $now = now();
                TenantActivityAward::query()->create([
                    'id' => 'awa_'.Str::ulid()->toBase32(),
                    'tenant_id' => (string) $tenantId,
                    'activity_id' => (string) $best['activity']->id,
                    'game_id' => (string) $result->game_id,
                    'customer_id' => $customerId,
                    'entry_id' => null,
                    'type' => 'cashback',
                    'prediction_type' => null,
                    'amount' => (int) $best['amount'],
                    'currency' => (string) $best['config']->currency,
                    'status' => 'claimable',
                    'calculated_at' => $now,
                    'metadata_json' => [
                        'ticket_count' => (int) $customer->ticket_count,
                        'purchase_amount' => (int) $customer->purchase_amount,
                    ],
                    'created_at' => $now,
                    'updated_at' => $now,
                ]);
                $created++;
            }
        }

        return $created;
    }

    private function createAutomaticActivityClaimsForGame(string $gameId): void
    {
        if (! Schema::hasColumn('customers', 'auto_reward_claim_enabled') || ! Schema::hasColumn('customers', 'auto_reward_claim_payout_method')) {
            return;
        }

        TenantActivityAward::query()
            ->where('game_id', $gameId)
            ->where('status', 'claimable')
            ->orderBy('id')
            ->chunkById(200, function ($awards): void {
                foreach ($awards as $award) {
                    $this->createAutomaticActivityClaimForAward((string) $award->id, $award->calculated_at);
                }
            });
    }

    private function createAutomaticActivityClaimForAward(string $awardId, mixed $submittedAt = null): ?string
    {
        return DB::transaction(function () use ($awardId, $submittedAt): ?string {
            $award = TenantActivityAward::query()
                ->whereKey($awardId)
                ->lockForUpdate()
                ->first();

            if ($award === null || (string) $award->status !== 'claimable') {
                return null;
            }

            if (ActivityClaim::query()->forTenant((string) $award->tenant_id)->where('activity_award_id', $award->id)->whereNotIn('status', ['rejected', 'cancelled'])->exists()) {
                return null;
            }

            $customer = Customer::query()
                ->where('tenant_id', (string) $award->tenant_id)
                ->whereKey((string) $award->customer_id)
                ->where('auto_reward_claim_enabled', true)
                ->first([
                    'id',
                    'tenant_id',
                    'auto_reward_claim_payout_method',
                    'reward_payout_bank_account_json',
                ]);

            if ($customer === null) {
                return null;
            }

            $payoutMethod = $this->normalizeAutomaticActivityPayoutMethod($customer->auto_reward_claim_payout_method ?? null);
            $bankAccount = [];
            $walletId = null;

            if ($payoutMethod === 'bank_transfer') {
                $bankAccount = $this->decodeJsonObject($customer->reward_payout_bank_account_json ?? null);

                if (! $this->hasUsableBankAccount($bankAccount)) {
                    return null;
                }
            } else {
                $walletId = $this->customerAuth->ensurePrimaryWallet((string) $award->tenant_id, (string) $award->customer_id);
            }

            $claimId = 'acl_'.Str::ulid()->toBase32();
            $now = $submittedAt instanceof Carbon ? $submittedAt : now();
            $normalized = [
                'source' => 'auto_activity_claim',
                'activity_award_id' => (string) $award->id,
                'payout_method' => $payoutMethod,
            ];

            ActivityClaim::query()->create([
                'id' => $claimId,
                'tenant_id' => (string) $award->tenant_id,
                'activity_award_id' => (string) $award->id,
                'activity_id' => (string) $award->activity_id,
                'game_id' => (string) $award->game_id,
                'customer_id' => (string) $award->customer_id,
                'wallet_id' => $walletId,
                'payout_ledger_id' => null,
                'reference' => 'ACT-'.strtoupper(substr($claimId, -10)),
                'status' => 'submitted',
                'payout_method' => $payoutMethod,
                'claim_amount' => (int) $award->amount,
                'currency' => (string) $award->currency,
                'bank_account_json' => $bankAccount === [] ? null : json_encode($bankAccount, JSON_THROW_ON_ERROR),
                'customer_note' => null,
                'admin_note' => null,
                'idempotency_key' => null,
                'payload_hash' => sha1(json_encode($normalized, JSON_THROW_ON_ERROR)),
                'submitted_at' => $now,
                'created_at' => $now,
                'updated_at' => $now,
            ]);

            TenantActivityAward::query()->whereKey((string) $award->id)->update([
                'status' => 'claimed',
                'updated_at' => $now,
            ]);
            $this->queueTenantMenuBadgeBroadcast((string) $award->tenant_id, 'activity_claims');
            $this->queueActivityClaimUpdatedBroadcast((string) $award->tenant_id, $claimId);

            return $claimId;
        });
    }

    private function queueActivityClaimUpdatedBroadcast(string $tenantId, string $claimId): void
    {
        DB::afterCommit(function () use ($tenantId, $claimId): void {
            $claim = ActivityClaim::query()
                ->forTenant($tenantId)
                ->with(['award', 'activity', 'customer'])
                ->where('id', $claimId)
                ->first();

            if ($claim === null) {
                return;
            }

            ActivityClaimUpdated::dispatch([
                'event_type' => 'activity.claim.updated',
                'tenant_id' => $tenantId,
                'customer_id' => (string) $claim->customer_id,
                'claim_id' => $claimId,
                'claim' => $this->claimResource($claim),
                'updated_at' => now()->toISOString(),
            ]);
        });
    }

    private function queueTenantMenuBadgeBroadcast(string $tenantId, string $source): void
    {
        if (DB::transactionLevel() > 0) {
            DB::afterCommit(fn (): mixed => AdminMenuBadgesUpdated::dispatch('tenant', $tenantId, $source));

            return;
        }

        AdminMenuBadgesUpdated::dispatch('tenant', $tenantId, $source);
    }

    private function normalizeAutomaticActivityPayoutMethod(mixed $value): string
    {
        return trim((string) $value) === 'bank_transfer' ? 'bank_transfer' : 'wallet_credit';
    }

    private function activityQuery(string $tenantId): mixed
    {
        return TenantActivity::query()
            ->forTenant($tenantId)
            ->with(['game', 'fullAsset', 'thumbAsset', 'luckyConfig', 'cashbackConfig']);
    }

    private function activeQuery(string $tenantId): mixed
    {
        return $this->activityQuery($tenantId)
            ->where('status', 'active');
    }

    /**
     * @param array<string, mixed> $queryParams
     * @return array{selected_game_id: string|null, current_game_id: string|null, games: array<int, array<string, mixed>>, all_games: array<int, array<string, mixed>>, mode: string}
     */
    private function activityGameContext(
        string $tenantId,
        array $queryParams,
        bool $historyMode = false,
        bool $allowGameSelection = false,
        bool $activeOnly = true,
    ): array
    {
        $allGames = $this->activityGameOptions($tenantId, $activeOnly);
        $currentGameId = $this->currentActivityGameId($allGames);
        $games = $historyMode
            ? array_values(array_filter(
                $allGames,
                fn (array $game): bool => (string) $game['id'] !== (string) ($currentGameId ?? ''),
            ))
            : $allGames;
        $gameIds = array_map(fn (array $game): string => (string) $game['id'], $games);
        $requestedGameId = trim((string) ($queryParams['game_id'] ?? ''));
        $selectedGameId = null;

        if (($historyMode || $allowGameSelection) && $requestedGameId !== '' && in_array($requestedGameId, $gameIds, true)) {
            $selectedGameId = $requestedGameId;
        } elseif ($historyMode) {
            $selectedGameId = $games[0]['id'] ?? null;
        } else {
            $selectedGameId = $currentGameId;
        }

        return [
            'selected_game_id' => $selectedGameId,
            'current_game_id' => $currentGameId,
            'games' => $games,
            'all_games' => $allGames,
            'mode' => $historyMode ? 'history' : 'current',
        ];
    }

    /**
     * @param array<string, mixed> $queryParams
     * @param array{selected_game_id: string|null, current_game_id: string|null, games: array<int, array<string, mixed>>, all_games?: array<int, array<string, mixed>>, mode?: string} $gameContext
     * @return array{0: array<int, object>, 1: bool, 2: string|null}
     */
    private function activeActivityPage(string $tenantId, array $queryParams, array $gameContext, int $limit): array
    {
        $query = $this->activeQuery($tenantId)
            ->when(
                $gameContext['selected_game_id'] !== null,
                fn ($query) => $query->where('game_id', $gameContext['selected_game_id']),
            );

        $cursor = $this->decodeActivityCursor($queryParams['cursor'] ?? null);

        if ($cursor !== null) {
            $query->where(function ($builder) use ($cursor): void {
                $builder
                    ->where('sort_order', '<', $cursor['sort_order'])
                    ->orWhere(function ($builder) use ($cursor): void {
                        $builder
                            ->where('sort_order', $cursor['sort_order'])
                            ->where('updated_at', '<', $cursor['updated_at']);
                    })
                    ->orWhere(function ($builder) use ($cursor): void {
                        $builder
                            ->where('sort_order', $cursor['sort_order'])
                            ->where('updated_at', $cursor['updated_at'])
                            ->where('id', '<', $cursor['id']);
                    });
            });
        }

        $rows = $query
            ->orderByDesc('sort_order')
            ->orderByDesc('updated_at')
            ->orderByDesc('id')
            ->limit($limit + 1)
            ->get()
            ->all();

        $hasMore = count($rows) > $limit;
        $rows = array_slice($rows, 0, $limit);

        return [
            $rows,
            $hasMore,
            $hasMore && $rows !== [] ? $this->encodeActivityCursor(end($rows)) : null,
        ];
    }

    /**
     * @return array{sort_order: int, updated_at: Carbon, id: string}|null
     */
    private function decodeActivityCursor(mixed $value): ?array
    {
        $cursor = trim((string) $value);

        if ($cursor === '') {
            return null;
        }

        $decoded = $this->base64UrlDecode($cursor);

        if ($decoded === null) {
            return null;
        }

        try {
            $payload = json_decode($decoded, true, flags: JSON_THROW_ON_ERROR);

            if (! is_array($payload) || trim((string) ($payload['id'] ?? '')) === '') {
                return null;
            }

            return [
                'sort_order' => (int) ($payload['sort_order'] ?? 0),
                'updated_at' => Carbon::parse((string) ($payload['updated_at'] ?? '')),
                'id' => trim((string) $payload['id']),
            ];
        } catch (\Throwable) {
            return null;
        }
    }

    private function encodeActivityCursor(object $row): string
    {
        $updatedAt = $row->updated_at instanceof Carbon
            ? $row->updated_at->toJSON()
            : Carbon::parse((string) $row->updated_at)->toJSON();

        return $this->base64UrlEncode(json_encode([
            'sort_order' => (int) ($row->sort_order ?? 0),
            'updated_at' => $updatedAt,
            'id' => (string) $row->id,
        ], JSON_THROW_ON_ERROR));
    }

    private function base64UrlEncode(string $value): string
    {
        return rtrim(strtr(base64_encode($value), '+/', '-_'), '=');
    }

    private function base64UrlDecode(string $value): ?string
    {
        $padded = $value.str_repeat('=', (4 - strlen($value) % 4) % 4);
        $decoded = base64_decode(strtr($padded, '-_', '+/'), true);

        return $decoded === false ? null : $decoded;
    }

    private function activityListMeta(array $context, ?string $nextCursor = null, bool $hasMore = false): array
    {
        return [
            'has_more' => $hasMore,
            'next_cursor' => $nextCursor,
            'selected_game_id' => $context['selected_game_id'],
            'current_game_id' => $context['current_game_id'],
            'games' => $context['games'],
            'has_history' => $this->hasActivityHistory($context),
            'mode' => $context['mode'] ?? 'current',
        ];
    }

    /**
     * @param array<int, array<string, mixed>> $games
     */
    private function currentActivityGameId(array $games): ?string
    {
        $openGameId = Game::query()
            ->where('status', 'open')
            ->orderByDesc('draw_at')
            ->orderByDesc('created_at')
            ->value('id');

        if ($openGameId !== null) {
            return (string) $openGameId;
        }

        foreach ($games as $game) {
            if ((string) ($game['status'] ?? '') === 'open') {
                return (string) $game['id'];
            }
        }

        return $games[0]['id'] ?? null;
    }

    /**
     * @return array<int, array<string, mixed>>
     */
    private function activityGameOptions(string $tenantId, bool $activeOnly = true): array
    {
        $query = DB::table('tenant_activities')
            ->join('games', 'games.id', '=', 'tenant_activities.game_id')
            ->where('tenant_activities.tenant_id', $tenantId);

        if ($activeOnly) {
            $query->where('tenant_activities.status', 'active');
        }

        return $query
            ->groupBy('games.id', 'games.code', 'games.name', 'games.status', 'games.sale_start_at', 'games.draw_at', 'games.close_at', 'games.created_at')
            ->orderByDesc('games.draw_at')
            ->orderByDesc('games.created_at')
            ->get([
                'games.id',
                'games.code',
                'games.name',
                'games.status',
                'games.sale_start_at',
                'games.draw_at',
                'games.close_at',
                DB::raw('COUNT(tenant_activities.id) as activity_count'),
            ])
            ->map(fn (object $game): array => [
                'id' => (string) $game->id,
                'code' => (string) $game->code,
                'name' => (string) $game->name,
                'label' => $this->activityGameLabel($game),
                'status' => (string) $game->status,
                'sale_start_at' => $game->sale_start_at,
                'draw_at' => $game->draw_at,
                'close_at' => $game->close_at,
                'activity_count' => (int) $game->activity_count,
            ])
            ->all();
    }

    /**
     * @param array{current_game_id: string|null, games: array<int, array<string, mixed>>, all_games?: array<int, array<string, mixed>>} $context
     */
    private function hasActivityHistory(array $context): bool
    {
        $games = $context['all_games'] ?? $context['games'];

        return count(array_filter(
            $games,
            fn (array $game): bool => (string) $game['id'] !== (string) ($context['current_game_id'] ?? ''),
        )) > 0;
    }

    private function truthy(mixed $value): bool
    {
        return filter_var($value, FILTER_VALIDATE_BOOLEAN, FILTER_NULL_ON_FAILURE) === true;
    }

    private function activityGameLabel(object $game): string
    {
        $name = trim((string) ($game->name ?? ''));

        if ($name !== '') {
            return $name;
        }

        if ($game->draw_at !== null) {
            return 'งวดวันที่ '.Carbon::parse($game->draw_at, self::BUSINESS_TIMEZONE)->locale('th')->translatedFormat('j M Y');
        }

        return (string) $game->id;
    }

    /**
     * @param array<string, mixed> $payload
     * @return array<string, mixed>
     */
    private function basePayload(array $payload, bool $creating, ?object $existing = null): array
    {
        $name = array_key_exists('name', $payload) ? trim((string) $payload['name']) : null;
        return array_filter([
            'name' => $name,
            'name_i18n' => array_key_exists('name_i18n', $payload) ? $this->normalizedLocalizedText($payload['name_i18n']) : null,
            'game_id' => array_key_exists('game_id', $payload) ? trim((string) $payload['game_id']) : ($creating ? '' : null),
            'type' => array_key_exists('type', $payload) ? trim((string) $payload['type']) : ($creating ? 'lucky_board' : null),
            'status' => array_key_exists('status', $payload) ? trim((string) $payload['status']) : ($creating ? 'draft' : null),
            'sort_order' => array_key_exists('sort_order', $payload) ? filter_var($payload['sort_order'], FILTER_VALIDATE_INT) : ($creating ? 0 : null),
            'metadata_json' => array_key_exists('metadata', $payload) && is_array($payload['metadata'])
                ? array_replace_recursive(is_array($existing?->metadata_json) ? $existing->metadata_json : [], $payload['metadata'])
                : null,
        ], fn (mixed $value): bool => $value !== null);
    }

    /**
     * @param array<string, mixed> $payload
     * @return array<string, array<int, string>>
     */
    private function baseErrors(string $tenantId, array $payload, bool $creating): array
    {
        $errors = [];

        foreach (['name', 'game_id', 'type'] as $field) {
            if ($creating && (! array_key_exists($field, $payload) || trim((string) $payload[$field]) === '')) {
                $errors[$field][] = 'The '.$field.' field is required.';
            }
        }

        if (array_key_exists('name', $payload) && (trim((string) $payload['name']) === '' || mb_strlen((string) $payload['name']) > 255)) {
            $errors['name'][] = 'The name field must be 1-255 characters.';
        }

        if (array_key_exists('slug', $payload) && (trim((string) $payload['slug']) === '' || strlen((string) $payload['slug']) > 180)) {
            $errors['slug'][] = 'The slug field must be 1-180 characters.';
        }

        if (array_key_exists('type', $payload) && ! in_array($payload['type'], self::TYPES, true)) {
            $errors['type'][] = 'The type field is invalid.';
        }

        if (array_key_exists('status', $payload) && ! in_array($payload['status'], self::STATUSES, true)) {
            $errors['status'][] = 'The status field is invalid.';
        }

        if (array_key_exists('sort_order', $payload) && $payload['sort_order'] === false) {
            $errors['sort_order'][] = 'The sort_order field must be an integer.';
        }

        if (array_key_exists('name_i18n', $payload) && ! is_array($payload['name_i18n'])) {
            $errors['name_i18n'][] = 'The name_i18n field must be an object keyed by locale.';
        }

        if (array_key_exists('game_id', $payload) && trim((string) $payload['game_id']) !== '') {
            $gameExists = Game::query()->whereKey((string) $payload['game_id'])->exists();
            if (! $gameExists) {
                $errors['game_id'][] = 'The selected game was not found.';
            }
        }

        return $errors;
    }

    /**
     * @param array<string, mixed> $payload
     * @return array<string, mixed>
     */
    private function configPayload(string $type, array $payload): array
    {
        $config = is_array($payload['config'] ?? null) ? $payload['config'] : $payload;

        if ($type === 'cashback') {
            $minimumType = $this->cashbackMinimumTypeFromPayload($config);
            $minTicketCount = max(0, $this->intValue($config['min_ticket_count'] ?? 0));
            $minPurchaseAmount = $this->minorAmount($config['min_purchase_amount'] ?? 0);

            return [
                'cashback_type' => trim((string) ($config['cashback_type'] ?? 'percent')),
                'cashback_percent_bps' => $this->intValue($config['cashback_percent_bps'] ?? 0),
                'fixed_amount' => $this->minorAmount($config['fixed_amount'] ?? 0),
                'minimum_type' => $minimumType,
                'min_ticket_count' => $minimumType === 'tickets' ? $minTicketCount : 0,
                'min_purchase_amount' => $minimumType === 'amount' ? $minPurchaseAmount : 0,
                'currency' => 'THB',
            ];
        }

        if ($type === 'lucky_board') {
            $predictionType = $this->selectedPredictionTypeFromPayload($config);

            return [
                'prediction_type' => $predictionType,
                'first_prize_last2_enabled' => $predictionType === 'first_prize_last2',
                'first_prize_last3_enabled' => $predictionType === 'first_prize_last3',
                'last2_enabled' => $predictionType === 'last2',
                'eligibility_rule' => trim((string) ($config['eligibility_rule'] ?? 'cumulative_tickets')),
                'threshold_tickets' => max(1, $this->intValue($config['threshold_tickets'] ?? 1)),
                'first_prize_last2_amount' => $this->minorAmount($config['first_prize_last2_amount'] ?? 0),
                'first_prize_last3_amount' => $this->minorAmount($config['first_prize_last3_amount'] ?? 0),
                'last2_amount' => $this->minorAmount($config['last2_amount'] ?? 0),
                'currency' => 'THB',
            ];
        }

        return [];
    }

    /**
     * @param array<string, mixed> $config
     * @return array<string, array<int, string>>
     */
    private function configErrors(string $type, array $config): array
    {
        $errors = [];

        if ($type === 'lucky_board') {
            if (! in_array($config['eligibility_rule'] ?? '', self::LUCKY_RULES, true)) {
                $errors['config.eligibility_rule'][] = 'The eligibility_rule field is invalid.';
            }

            if (($config['threshold_tickets'] ?? 0) < 1) {
                $errors['config.threshold_tickets'][] = 'The threshold_tickets field must be at least 1.';
            }

            if (! in_array($config['prediction_type'] ?? '', self::PREDICTION_TYPES, true)) {
                $errors['config.prediction_type'][] = 'The prediction_type field is invalid.';
            }

            $enabledCount = count(array_filter([
                $config['first_prize_last2_enabled'] ?? false,
                $config['first_prize_last3_enabled'] ?? false,
                $config['last2_enabled'] ?? false,
            ]));
            if ($enabledCount !== 1) {
                $errors['config.prediction_type'][] = 'Exactly one prediction type must be selected.';
            }
        }

        if ($type === 'cashback') {
            if (! in_array($config['cashback_type'] ?? '', self::CASHBACK_TYPES, true)) {
                $errors['config.cashback_type'][] = 'The cashback_type field is invalid.';
            }

            if (($config['cashback_type'] ?? '') === 'percent' && (($config['cashback_percent_bps'] ?? 0) < 1 || ($config['cashback_percent_bps'] ?? 0) > 10000)) {
                $errors['config.cashback_percent_bps'][] = 'The cashback_percent_bps field must be between 1 and 10000.';
            }

            if (($config['cashback_type'] ?? '') === 'fixed' && ($config['fixed_amount'] ?? 0) < 1) {
                $errors['config.fixed_amount'][] = 'The fixed_amount field must be greater than zero.';
            }

            if (! in_array($config['minimum_type'] ?? '', self::CASHBACK_MINIMUM_TYPES, true)) {
                $errors['config.minimum_type'][] = 'The minimum_type field is invalid.';
            }
        }

        return $errors;
    }

    /**
     * @param array<string, mixed> $config
     */
    private function storeConfig(string $activityId, string $type, array $config): void
    {
        $now = now();

        if ($type === 'lucky_board') {
            TenantActivityCashbackConfig::query()->where('activity_id', $activityId)->delete();
            $dbConfig = $config;
            unset($dbConfig['prediction_type']);
            TenantActivityLuckyConfig::query()->updateOrCreate(
                ['activity_id' => $activityId],
                $dbConfig + ['updated_at' => $now, 'created_at' => $now],
            );
            return;
        }

        if ($type === 'cashback') {
            TenantActivityLuckyConfig::query()->where('activity_id', $activityId)->delete();
            $dbConfig = $config;
            unset($dbConfig['minimum_type']);
            TenantActivityCashbackConfig::query()->updateOrCreate(
                ['activity_id' => $activityId],
                $dbConfig + ['updated_at' => $now, 'created_at' => $now],
            );
        }
    }

    private function hasParticipation(string $activityId): bool
    {
        return TenantActivityEntry::query()->where('activity_id', $activityId)->exists()
            || TenantActivityAward::query()->where('activity_id', $activityId)->exists()
            || ActivityClaim::query()->where('activity_id', $activityId)->exists();
    }

    /**
     * @return array<string, mixed>
     */
    private function rightsSummary(string $tenantId, string $customerId, string $activityId): array
    {
        $activity = TenantActivity::query()->forTenant($tenantId)->with(['game', 'luckyConfig'])->where('id', $activityId)->first();
        $config = $activity?->luckyConfig;

        if ($activity === null || $config === null || (string) $activity->type !== 'lucky_board') {
            return [
                'earned_count' => 0,
                'used_count' => 0,
                'remaining_count' => 0,
                'ticket_count' => 0,
                'qualifying_order_count' => 0,
            ];
        }

        $threshold = max(1, (int) $config->threshold_tickets);
        $orders = $this->paidOrderTicketSummaries($tenantId, (string) $activity->game_id, $customerId);
        $ticketCount = array_sum(array_map(fn (array $order): int => (int) $order['ticket_count'], $orders));
        $usedByOrder = $this->usedLuckyTicketCountsByOrder($tenantId, (string) $activity->game_id, $customerId);
        $usedByOtherOrder = $this->usedLuckyTicketCountsByOrder($tenantId, (string) $activity->game_id, $customerId, $activityId);
        $rule = (string) $config->eligibility_rule;
        $earned = $rule === 'single_order_exact_tickets'
            ? $this->singleOrderRightsFromOrders($orders, $usedByOtherOrder, $threshold)
            : intdiv(max(0, $ticketCount - array_sum($usedByOtherOrder)), $threshold);
        $remaining = $rule === 'single_order_exact_tickets'
            ? $this->singleOrderRightsFromOrders($orders, $usedByOrder, $threshold)
            : intdiv(max(0, $ticketCount - array_sum($usedByOrder)), $threshold);
        $used = TenantActivityEntry::query()
            ->forTenant($tenantId)
            ->where('activity_id', $activityId)
            ->where('customer_id', $customerId)
            ->where('status', '!=', 'cancelled')
            ->count();

        return [
            'earned_count' => (int) $earned,
            'used_count' => (int) $used,
            'remaining_count' => max(0, (int) $remaining),
            'ticket_count' => $ticketCount,
            'available_ticket_count' => max(0, $ticketCount - array_sum($usedByOrder)),
            'consumed_ticket_count' => array_sum($usedByOrder),
            'qualifying_order_count' => $rule === 'single_order_exact_tickets'
                ? $this->singleOrderQualifyingOrderCount($orders, $usedByOtherOrder, $threshold)
                : 0,
            'eligibility_rule' => $rule,
            'threshold_tickets' => $threshold,
            'entry_deadline_at' => $this->luckyBoardEntryDeadlineAt($activity)?->toIso8601String(),
            'entry_closed' => $this->luckyBoardEntryClosed($activity),
            'entry_close_after_minutes' => 30,
        ];
    }

    /**
     * @return array<string, mixed>
     */
    private function cashbackProgress(string $tenantId, string $customerId, object $activity): array
    {
        $config = $activity->cashbackConfig;
        $summary = $this->paidCustomerSummary($tenantId, (string) $activity->game_id, $customerId);
        $eligible = $config !== null && $this->passesCashbackConfig($summary, $config);
        $estimatedAmount = $summary !== null && $config !== null
            ? max(0, $this->cashbackAmount((int) $summary->purchase_amount, $config))
            : 0;

        return [
            'ticket_count' => (int) ($summary?->ticket_count ?? 0),
            'purchase_amount' => $this->money((int) ($summary?->purchase_amount ?? 0)),
            'minimum_type' => $this->cashbackMinimumTypeFromConfig($config),
            'min_ticket_count' => $this->cashbackMinimumTypeFromConfig($config) === 'tickets' ? (int) ($config?->min_ticket_count ?? 0) : 0,
            'min_purchase_amount' => $this->money($this->cashbackMinimumTypeFromConfig($config) === 'amount' ? (int) ($config?->min_purchase_amount ?? 0) : 0),
            'eligible_by_purchase' => $eligible,
            'estimated_amount' => $this->money($eligible ? $estimatedAmount : 0, (string) ($config?->currency ?? 'THB')),
            'potential_amount' => $this->money($estimatedAmount, (string) ($config?->currency ?? 'THB')),
        ];
    }

    /**
     * @return array<int, array<string, mixed>>
     */
    private function customerEntries(string $tenantId, string $customerId, string $activityId): array
    {
        return TenantActivityEntry::query()
            ->forTenant($tenantId)
            ->where('customer_id', $customerId)
            ->where('activity_id', $activityId)
            ->orderByDesc('created_at')
            ->get()
            ->map(fn (object $entry): array => $this->entryResource($entry))
            ->all();
    }

    private function paidTicketCount(string $tenantId, string $gameId, string $customerId): int
    {
        return Ticket::query()
            ->join('orders', 'orders.id', '=', 'tickets.order_id')
            ->where('tickets.tenant_id', $tenantId)
            ->where('tickets.game_id', $gameId)
            ->where('tickets.customer_id', $customerId)
            ->where('orders.status', 'paid')
            ->where('orders.payment_status', 'paid')
            ->count('tickets.id');
    }

    /**
     * @return array<int, array{id: string, ticket_count: int}>
     */
    private function paidOrderTicketSummaries(string $tenantId, string $gameId, string $customerId): array
    {
        return Order::query()
            ->join('tickets', 'tickets.order_id', '=', 'orders.id')
            ->where('orders.tenant_id', $tenantId)
            ->where('orders.game_id', $gameId)
            ->where('orders.customer_id', $customerId)
            ->where('orders.status', 'paid')
            ->where('orders.payment_status', 'paid')
            ->select(['orders.id'])
            ->selectRaw('COUNT(tickets.id) as ticket_count')
            ->groupBy('orders.id', 'orders.created_at')
            ->orderBy('orders.created_at')
            ->orderBy('orders.id')
            ->get()
            ->map(fn (object $order): array => [
                'id' => (string) $order->id,
                'ticket_count' => (int) $order->ticket_count,
            ])
            ->all();
    }

    private function qualifyingExactOrderCount(string $tenantId, string $gameId, string $customerId, int $threshold): int
    {
        return Order::query()
            ->join('tickets', 'tickets.order_id', '=', 'orders.id')
            ->where('orders.tenant_id', $tenantId)
            ->where('orders.game_id', $gameId)
            ->where('orders.customer_id', $customerId)
            ->where('orders.status', 'paid')
            ->where('orders.payment_status', 'paid')
            ->select('orders.id')
            ->groupBy('orders.id')
            ->havingRaw('COUNT(tickets.id) = ?', [$threshold])
            ->get()
            ->count();
    }

    /**
     * @return array{source_type: string, source_id: string|null, metadata: array<string, mixed>}|null
     */
    private function allocateLuckyRight(string $tenantId, string $customerId, object $activity): ?array
    {
        $config = $activity->luckyConfig;

        if ($config === null) {
            return null;
        }

        $threshold = max(1, (int) $config->threshold_tickets);
        $orders = $this->paidOrderTicketSummaries($tenantId, (string) $activity->game_id, $customerId);
        $usedByOrder = $this->usedLuckyTicketCountsByOrder($tenantId, (string) $activity->game_id, $customerId);
        $rule = (string) $config->eligibility_rule;
        $allocations = $rule === 'single_order_exact_tickets'
            ? $this->allocateSingleOrderTickets($orders, $usedByOrder, $threshold)
            : $this->allocateCumulativeTickets($orders, $usedByOrder, $threshold);

        if ($allocations === []) {
            return null;
        }

        $sourceType = $rule === 'single_order_exact_tickets' ? 'order_tickets' : 'ticket_pool';

        return [
            'source_type' => $sourceType,
            'source_id' => count($allocations) === 1 ? (string) $allocations[0]['order_id'] : null,
            'metadata' => [
                'rights_rule' => $rule,
                'threshold_tickets' => $threshold,
                'ticket_count_consumed' => array_sum(array_map(fn (array $allocation): int => (int) $allocation['ticket_count'], $allocations)),
                'allocations' => $allocations,
            ],
        ];
    }

    /**
     * @param array<int, array{id: string, ticket_count: int}> $orders
     * @param array<string, int> $usedByOrder
     * @return array<int, array{order_id: string, ticket_count: int}>
     */
    private function allocateCumulativeTickets(array $orders, array $usedByOrder, int $threshold): array
    {
        $remaining = $threshold;
        $allocations = [];

        foreach ($orders as $order) {
            $available = max(0, (int) $order['ticket_count'] - (int) ($usedByOrder[$order['id']] ?? 0));
            if ($available < 1) {
                continue;
            }

            $take = min($available, $remaining);
            $allocations[] = [
                'order_id' => (string) $order['id'],
                'ticket_count' => $take,
            ];
            $remaining -= $take;

            if ($remaining === 0) {
                return $allocations;
            }
        }

        return [];
    }

    /**
     * @param array<int, array{id: string, ticket_count: int}> $orders
     * @param array<string, int> $usedByOrder
     * @return array<int, array{order_id: string, ticket_count: int}>
     */
    private function allocateSingleOrderTickets(array $orders, array $usedByOrder, int $threshold): array
    {
        foreach ($orders as $order) {
            $available = max(0, (int) $order['ticket_count'] - (int) ($usedByOrder[$order['id']] ?? 0));
            if ($available >= $threshold) {
                return [[
                    'order_id' => (string) $order['id'],
                    'ticket_count' => $threshold,
                ]];
            }
        }

        return [];
    }

    /**
     * @param array<int, array{id: string, ticket_count: int}> $orders
     * @param array<string, int> $usedByOrder
     */
    private function singleOrderRightsFromOrders(array $orders, array $usedByOrder, int $threshold): int
    {
        return array_sum(array_map(
            fn (array $order): int => intdiv(max(0, (int) $order['ticket_count'] - (int) ($usedByOrder[$order['id']] ?? 0)), $threshold),
            $orders,
        ));
    }

    /**
     * @param array<int, array{id: string, ticket_count: int}> $orders
     * @param array<string, int> $usedByOrder
     */
    private function singleOrderQualifyingOrderCount(array $orders, array $usedByOrder, int $threshold): int
    {
        return count(array_filter(
            $orders,
            fn (array $order): bool => max(0, (int) $order['ticket_count'] - (int) ($usedByOrder[$order['id']] ?? 0)) >= $threshold,
        ));
    }

    /**
     * @return array<string, int>
     */
    private function usedLuckyTicketCountsByOrder(string $tenantId, string $gameId, string $customerId, ?string $excludeActivityId = null): array
    {
        $orders = $this->paidOrderTicketSummaries($tenantId, $gameId, $customerId);
        $usedByOrder = array_fill_keys(array_map(fn (array $order): string => (string) $order['id'], $orders), 0);
        $entries = TenantActivityEntry::query()
            ->forTenant($tenantId)
            ->where('game_id', $gameId)
            ->where('customer_id', $customerId)
            ->where('status', '!=', 'cancelled')
            ->with(['activity.luckyConfig'])
            ->orderBy('created_at')
            ->orderBy('id')
            ->get()
            ->all();

        foreach ($entries as $entry) {
            if ($excludeActivityId !== null && (string) $entry->activity_id === $excludeActivityId) {
                continue;
            }

            $threshold = max(1, (int) ($entry->activity?->luckyConfig?->threshold_tickets ?? 1));
            $this->applyEntryTicketConsumption($usedByOrder, $orders, $entry, $threshold);
        }

        return $usedByOrder;
    }

    /**
     * @param array<string, int> $usedByOrder
     * @param array<int, array{id: string, ticket_count: int}> $orders
     */
    private function applyEntryTicketConsumption(array &$usedByOrder, array $orders, object $entry, int $threshold): void
    {
        $metadata = $this->decodeJsonObject($entry->metadata_json ?? null);
        $allocations = is_array($metadata['allocations'] ?? null) ? $metadata['allocations'] : [];

        if ($allocations !== []) {
            foreach ($allocations as $allocation) {
                if (! is_array($allocation)) {
                    continue;
                }

                $orderId = (string) ($allocation['order_id'] ?? '');
                $ticketCount = max(0, (int) ($allocation['ticket_count'] ?? 0));
                if ($orderId !== '' && array_key_exists($orderId, $usedByOrder) && $ticketCount > 0) {
                    $usedByOrder[$orderId] += $ticketCount;
                }
            }

            return;
        }

        $sourceId = (string) ($entry->rights_source_id ?? '');
        if ($sourceId !== '' && array_key_exists($sourceId, $usedByOrder)) {
            $usedByOrder[$sourceId] += $threshold;
            return;
        }

        foreach ($this->allocateCumulativeTickets($orders, $usedByOrder, $threshold) as $allocation) {
            $usedByOrder[(string) $allocation['order_id']] += (int) $allocation['ticket_count'];
        }
    }

    private function paidCustomerSummary(string $tenantId, string $gameId, string $customerId): ?object
    {
        $ticketCounts = Ticket::query()
            ->where('tenant_id', $tenantId)
            ->where('game_id', $gameId)
            ->selectRaw('order_id, COUNT(id) as ticket_count')
            ->groupBy('order_id');

        return Order::query()
            ->leftJoinSub($ticketCounts, 'ticket_counts', fn ($join) => $join->on('ticket_counts.order_id', '=', 'orders.id'))
            ->where('orders.tenant_id', $tenantId)
            ->where('orders.game_id', $gameId)
            ->where('orders.customer_id', $customerId)
            ->where('orders.status', 'paid')
            ->where('orders.payment_status', 'paid')
            ->select([
                'orders.customer_id',
            ])
            ->selectRaw('COALESCE(SUM(ticket_counts.ticket_count), 0) as ticket_count')
            ->selectRaw('COALESCE(SUM(orders.total_amount), 0) as purchase_amount')
            ->groupBy('orders.customer_id')
            ->first();
    }

    /**
     * @return array<int, object>
     */
    private function paidCustomerSummaries(string $tenantId, string $gameId): array
    {
        $ticketCounts = Ticket::query()
            ->where('tenant_id', $tenantId)
            ->where('game_id', $gameId)
            ->selectRaw('order_id, COUNT(id) as ticket_count')
            ->groupBy('order_id');

        return Order::query()
            ->leftJoinSub($ticketCounts, 'ticket_counts', fn ($join) => $join->on('ticket_counts.order_id', '=', 'orders.id'))
            ->where('orders.tenant_id', $tenantId)
            ->where('orders.game_id', $gameId)
            ->where('orders.status', 'paid')
            ->where('orders.payment_status', 'paid')
            ->select([
                'orders.customer_id',
            ])
            ->selectRaw('COALESCE(SUM(ticket_counts.ticket_count), 0) as ticket_count')
            ->selectRaw('COALESCE(SUM(orders.total_amount), 0) as purchase_amount')
            ->groupBy('orders.customer_id')
            ->get()
            ->all();
    }

    /**
     * @return array<string, string>
     */
    private function winningPredictionNumbers(string $rewardResultId): array
    {
        $first = RewardPrize::query()
            ->where('reward_result_id', $rewardResultId)
            ->whereIn('prize_type', ['first_prize', 'reward_1'])
            ->whereRaw("prize_number NOT LIKE 'pending_%'")
            ->value('prize_number');
        $last2 = RewardPrize::query()
            ->where('reward_result_id', $rewardResultId)
            ->whereIn('prize_type', ['back2', 'reward_two_digit'])
            ->whereRaw("prize_number NOT LIKE 'pending_%'")
            ->value('prize_number');

        return [
            'first_prize_last2' => $first === null ? '' : substr(str_pad((string) $first, 6, '0', STR_PAD_LEFT), -2),
            'first_prize_last3' => $first === null ? '' : substr(str_pad((string) $first, 6, '0', STR_PAD_LEFT), -3),
            'last2' => $last2 === null ? '' : substr(str_pad((string) $last2, 2, '0', STR_PAD_LEFT), -2),
        ];
    }

    private function customerHasOfficialWinning(string $tenantId, string $gameId, string $customerId): bool
    {
        return WinningTicket::query()
            ->join('tickets', 'tickets.id', '=', 'winning_tickets.ticket_id')
            ->where('winning_tickets.tenant_id', $tenantId)
            ->where('winning_tickets.game_id', $gameId)
            ->where('tickets.customer_id', $customerId)
            ->exists();
    }

    private function customerHasLuckyWinning(string $tenantId, string $gameId, string $customerId): bool
    {
        return TenantActivityEntry::query()
            ->forTenant($tenantId)
            ->where('game_id', $gameId)
            ->where('customer_id', $customerId)
            ->where('status', 'won')
            ->exists();
    }

    private function passesCashbackConfig(?object $summary, object $config): bool
    {
        if ($summary === null) {
            return false;
        }

        if ($this->cashbackMinimumTypeFromConfig($config) === 'amount') {
            return (int) $summary->purchase_amount >= (int) $config->min_purchase_amount;
        }

        return (int) $summary->ticket_count >= (int) $config->min_ticket_count;
    }

    private function cashbackAmount(int $purchaseAmount, object $config): int
    {
        if ((string) $config->cashback_type === 'fixed') {
            return (int) $config->fixed_amount;
        }

        return (int) floor($purchaseAmount * (int) $config->cashback_percent_bps / 10000);
    }

    /**
     * @param array{activity: object, config: object, amount: int} $candidate
     * @param array{activity: object, config: object, amount: int} $best
     */
    private function cashbackCandidateIsBetter(array $candidate, array $best): bool
    {
        if ($candidate['amount'] !== $best['amount']) {
            return $candidate['amount'] > $best['amount'];
        }

        if ((int) $candidate['activity']->sort_order !== (int) $best['activity']->sort_order) {
            return (int) $candidate['activity']->sort_order > (int) $best['activity']->sort_order;
        }

        return strcmp((string) $candidate['activity']->updated_at, (string) $best['activity']->updated_at) > 0;
    }

    private function luckyPrizeAmount(object $config, string $predictionType): int
    {
        return match ($predictionType) {
            'first_prize_last2' => (int) $config->first_prize_last2_amount,
            'first_prize_last3' => (int) $config->first_prize_last3_amount,
            'last2' => (int) $config->last2_amount,
            default => 0,
        };
    }

    private function predictionEnabled(?object $config, string $predictionType): bool
    {
        if ($config === null) {
            return false;
        }

        return $predictionType === $this->selectedPredictionTypeFromConfig($config);
    }

    /**
     * @param array<string, mixed> $config
     */
    private function selectedPredictionTypeFromPayload(array $config): string
    {
        $candidate = trim((string) ($config['prediction_type'] ?? ''));
        if ($candidate !== '') {
            return in_array($candidate, self::PREDICTION_TYPES, true) ? $candidate : '';
        }

        foreach (self::PREDICTION_TYPES as $type) {
            $field = $type.'_enabled';
            if ($this->boolValue($config[$field] ?? false)) {
                return $type;
            }
        }

        return 'first_prize_last2';
    }

    private function selectedPredictionTypeFromConfig(?object $config): string
    {
        if ($config === null) {
            return 'first_prize_last2';
        }

        foreach (self::PREDICTION_TYPES as $type) {
            $field = $type.'_enabled';
            if ((bool) ($config->{$field} ?? false)) {
                return $type;
            }
        }

        return 'first_prize_last2';
    }

    /**
     * @param array<string, mixed> $config
     */
    private function cashbackMinimumTypeFromPayload(array $config): string
    {
        $candidate = trim((string) ($config['minimum_type'] ?? ''));
        $aliases = [
            'tickets' => 'tickets',
            'ticket_count' => 'tickets',
            'amount' => 'amount',
            'baht' => 'amount',
            'purchase_amount' => 'amount',
        ];

        if ($candidate !== '') {
            return $aliases[$candidate] ?? '';
        }

        if ($this->minorAmount($config['min_purchase_amount'] ?? 0) > 0 && max(0, $this->intValue($config['min_ticket_count'] ?? 0)) < 1) {
            return 'amount';
        }

        return 'tickets';
    }

    private function cashbackMinimumTypeFromConfig(?object $config): string
    {
        if ($config === null) {
            return 'tickets';
        }

        if ((int) ($config->min_purchase_amount ?? 0) > 0 && (int) ($config->min_ticket_count ?? 0) < 1) {
            return 'amount';
        }

        return 'tickets';
    }

    /**
     * @return array<string, array<int, string>>
     */
    private function imageErrors(?UploadedFile $file): array
    {
        $errors = [];

        if (! $file instanceof UploadedFile || ! $file->isValid()) {
            return ['file' => ['The file field is required and must be a valid upload.']];
        }

        if ((int) $file->getSize() < 1 || (int) $file->getSize() > self::MAX_IMAGE_BYTES) {
            $errors['file'][] = 'The image file must be between 1 byte and 8 MB.';
        }

        if (! str_starts_with((string) $file->getMimeType(), 'image/')) {
            $errors['file'][] = 'The uploaded file must be an image.';
        }

        return $errors;
    }

    /**
     * @return array{bytes: string, content_type: string, file_name: string, size_bytes: int, metadata: array<string, mixed>}
     */
    private function variantPayload(string $sourceBytes, int $maxWidth, int $quality, UploadedFile $file): array
    {
        $webpBytes = $this->resizedWebpBytes($sourceBytes, $maxWidth, $quality);
        $bytes = $webpBytes ?? $sourceBytes;
        $contentType = $webpBytes === null ? (string) ($file->getMimeType() ?: 'application/octet-stream') : 'image/webp';

        return [
            'bytes' => $bytes,
            'content_type' => $contentType,
            'file_name' => $webpBytes === null ? $file->getClientOriginalName() : 'activity.webp',
            'size_bytes' => strlen($bytes),
            'metadata' => [
                'source_file_name' => $file->getClientOriginalName(),
                'source_content_type' => $file->getClientMimeType(),
                'source_size_bytes' => (int) $file->getSize(),
                'max_width' => $maxWidth,
                'webp_conversion_status' => $webpBytes === null ? 'source_passthrough' : 'converted',
                'stored_checksum_sha256' => hash('sha256', $bytes),
            ],
        ];
    }

    private function resizedWebpBytes(string $sourceBytes, int $maxWidth, int $quality): ?string
    {
        if (! extension_loaded('gd') || ! function_exists('imagecreatefromstring') || ! function_exists('imagewebp')) {
            return null;
        }

        $image = @imagecreatefromstring($sourceBytes);

        if ($image === false) {
            return null;
        }

        try {
            $width = imagesx($image);
            $height = imagesy($image);
            $ratio = $width > $maxWidth ? $maxWidth / max(1, $width) : 1;
            $targetWidth = max(1, (int) round($width * $ratio));
            $targetHeight = max(1, (int) round($height * $ratio));
            $canvas = imagecreatetruecolor($targetWidth, $targetHeight);

            imagealphablending($canvas, false);
            imagesavealpha($canvas, true);
            imagecopyresampled($canvas, $image, 0, 0, 0, 0, $targetWidth, $targetHeight, $width, $height);

            ob_start();
            $ok = imagewebp($canvas, null, $quality);
            $bytes = ob_get_clean();
            imagedestroy($canvas);

            return $ok && is_string($bytes) && $bytes !== '' ? $bytes : null;
        } finally {
            imagedestroy($image);
        }
    }

    /**
     * @param array{bytes: string, content_type: string, file_name: string, size_bytes: int, metadata: array<string, mixed>} $payload
     */
    private function storeVariantAsset(string $tenantId, string $activityId, string $variant, array $payload, AdminSessionContext $actor): string
    {
        $assetId = 'ast_'.Str::ulid()->toBase32();
        $extension = $payload['content_type'] === 'image/webp'
            ? 'webp'
            : strtolower((string) pathinfo($payload['file_name'], PATHINFO_EXTENSION));
        $extension = $extension !== '' ? $extension : 'img';
        $storageKey = 'tenants/'.$tenantId.'/activities/'.$activityId.'/'.$variant.'.'.$extension;

        $storageKey = $this->storage->put(
            RuntimeStorageService::ROUTE_ACTIVITY_IMAGES,
            $storageKey,
            $payload['bytes'],
            ['ContentType' => $payload['content_type']],
        );

        PlatformAsset::query()->create([
            'id' => $assetId,
            'scope_type' => 'tenant',
            'tenant_id' => $tenantId,
            'created_by_admin_id' => $actor->adminUser['id'],
            'purpose' => self::PURPOSE,
            'file_name' => 'activity-'.$variant.'.'.$extension,
            'content_type' => $payload['content_type'],
            'size_bytes' => $payload['size_bytes'],
            'checksum_sha256' => $payload['metadata']['stored_checksum_sha256'] ?? null,
            'status' => 'committed',
            'storage_key' => $storageKey,
            'upload_url' => null,
            'public_url' => $this->storage->publicUrl(RuntimeStorageService::ROUTE_ACTIVITY_IMAGES, $storageKey),
            'metadata_json' => $payload['metadata'] + [
                'activity_id' => $activityId,
                'variant' => $variant,
                'storage_route' => RuntimeStorageService::ROUTE_ACTIVITY_IMAGES,
            ],
            'expires_at' => null,
            'committed_at' => now(),
            'created_at' => now(),
            'updated_at' => now(),
        ]);

        return $assetId;
    }

    /**
     * @return array<string, mixed>
     */
    private function resource(object $row, bool $includeStats = false): array
    {
        $fullAsset = $row->relationLoaded('fullAsset') ? $row->fullAsset : null;
        $thumbAsset = $row->relationLoaded('thumbAsset') ? $row->thumbAsset : null;
        $fullUrl = PublicUrl::normalizeAssetUrl($fullAsset?->public_url);
        $thumbUrl = PublicUrl::normalizeAssetUrl($thumbAsset?->public_url) ?: $fullUrl;
        $game = $row->relationLoaded('game') ? $row->game : null;
        $resultAt = $this->activityResultAt($game?->draw_at ?? null);
        $entryDeadlineAt = (string) $row->type === 'lucky_board' ? $this->luckyBoardEntryDeadlineAt($row) : null;
        $resource = [
            'id' => (string) $row->id,
            'tenant_id' => (string) $row->tenant_id,
            'game_id' => (string) $row->game_id,
            'name' => (string) $row->name,
            'title' => (string) $row->name,
            'name_i18n' => $this->decodedLocalizedText($row->name_i18n ?? null),
            'slug' => (string) $row->slug,
            'type' => (string) $row->type,
            'status' => (string) $row->status,
            'sort_order' => (int) $row->sort_order,
            'image_full_asset_id' => $row->image_full_asset_id,
            'image_thumb_asset_id' => $row->image_thumb_asset_id,
            'image_full_url' => $fullUrl,
            'image_thumb_url' => $thumbUrl,
            'cover' => $thumbUrl,
            'cover_url' => $thumbUrl,
            'url' => '/activities/'.(string) $row->slug,
            'result_at' => $resultAt?->toIso8601String(),
            'result_time_label' => '17:00',
            'entry_deadline_at' => $entryDeadlineAt?->toIso8601String(),
            'entry_closed' => $entryDeadlineAt !== null && now()->gte($entryDeadlineAt),
            'entry_close_after_minutes' => (string) $row->type === 'lucky_board' ? 30 : null,
            'game' => $game === null ? null : [
                'id' => (string) $game->id,
                'name' => $game->name ?? $game->draw_label ?? (string) $game->id,
                'draw_at' => $game->draw_at ?? null,
                'close_at' => $game->close_at ?? null,
                'status' => $game->status ?? null,
            ],
            'config' => $this->configResource($row),
            'metadata' => $row->metadata_json ?? [],
            'created_at' => $row->created_at?->toISOString(),
            'updated_at' => $row->updated_at?->toISOString(),
        ];

        if ($includeStats) {
            $resource['stats'] = [
                'entries_count' => TenantActivityEntry::query()->where('activity_id', $row->id)->count(),
                'awards_count' => TenantActivityAward::query()->where('activity_id', $row->id)->count(),
                'claims_count' => ActivityClaim::query()->where('activity_id', $row->id)->count(),
            ];
        }

        return $resource;
    }

    private function luckyBoardEntryDeadlineAt(object $activity): ?Carbon
    {
        $game = $activity->relationLoaded('game') ? $activity->game : null;
        $closeAt = $game?->close_at ?? null;

        if ($closeAt === null || trim((string) $closeAt) === '') {
            return null;
        }

        return Carbon::parse($closeAt)
            ->timezone(self::BUSINESS_TIMEZONE)
            ->addMinutes(30);
    }

    private function luckyBoardEntryClosed(object $activity): bool
    {
        $deadline = $this->luckyBoardEntryDeadlineAt($activity);

        return $deadline !== null && now()->gte($deadline);
    }

    /**
     * @return array<string, mixed>
     */
    private function publicResource(object $row, bool $includeBody = false): array
    {
        $resource = $this->resource($row);
        $localizedName = $this->localizedText($row->name_i18n ?? null, $row->name) ?? (string) $row->name;
        $resource['name'] = $localizedName;
        $resource['title'] = $localizedName;
        $resource['description'] = $this->activityDescription($row);

        if ((string) $row->type === 'lucky_board') {
            $resource['number_board'] = $this->luckyBoardResource($row, $includeBody);
            $resource['result_summary'] = $this->luckyBoardResultResource($row);
        }

        if (! $includeBody) {
            unset($resource['metadata']);
        }

        return $resource;
    }

    /**
     * @return array<string, mixed>
     */
    private function luckyBoardResource(object $row, bool $includeReservedNumbers = false): array
    {
        $config = $row->relationLoaded('luckyConfig') ? $row->luckyConfig : null;
        $predictionTypes = [$this->selectedPredictionTypeFromConfig($config)];
        $reservedByType = $this->reservedLuckyNumbersByPredictionType((string) $row->tenant_id, (string) $row->id, $predictionTypes);
        $types = [];

        foreach ($predictionTypes as $predictionType) {
            $digits = $predictionType === 'first_prize_last3' ? 3 : 2;
            $totalCount = $digits === 3 ? 1000 : 100;
            $reservedNumbers = $reservedByType[$predictionType] ?? [];
            $payload = [
                'prediction_type' => $predictionType,
                'digits' => $digits,
                'total_count' => $totalCount,
                'reserved_count' => count($reservedNumbers),
                'remaining_count' => max(0, $totalCount - count($reservedNumbers)),
            ];

            if ($includeReservedNumbers) {
                $payload['reserved_numbers'] = $reservedNumbers;
            }

            $types[$predictionType] = $payload;
        }

        $selected = $types[$predictionTypes[0]];

        return $selected + [
            'types' => $types,
        ];
    }

    /**
     * @return array<string, mixed>|null
     */
    private function luckyBoardResultResource(object $row, ?string $customerId = null): ?array
    {
        if ((string) $row->type !== 'lucky_board') {
            return null;
        }

        $result = RewardResult::query()
            ->where('game_id', $row->game_id)
            ->where('status', 'published')
            ->orderByDesc('published_at')
            ->orderByDesc('updated_at')
            ->first();

        if ($result === null) {
            return null;
        }

        $game = $row->relationLoaded('game') ? $row->game : null;
        $resultAt = $this->activityResultAt($game?->draw_at ?? null);
        if ($resultAt !== null && now()->lt($resultAt)) {
            return null;
        }

        $predictionType = $this->selectedPredictionTypeFromConfig($row->relationLoaded('luckyConfig') ? $row->luckyConfig : null);
        $winningNumbers = $this->winningPredictionNumbers((string) $result->id);
        $winningNumber = (string) ($winningNumbers[$predictionType] ?? '');

        if ($winningNumber === '') {
            return null;
        }

        $winnerCount = TenantActivityEntry::query()
            ->forTenant((string) $row->tenant_id)
            ->where('activity_id', $row->id)
            ->where('prediction_type', $predictionType)
            ->where('status', 'won')
            ->count();
        $awardTotal = (int) TenantActivityAward::query()
            ->forTenant((string) $row->tenant_id)
            ->where('activity_id', $row->id)
            ->where('type', 'lucky_board')
            ->where('prediction_type', $predictionType)
            ->sum('amount');

        $summary = [
            'status' => 'announced',
            'reward_result_id' => (string) $result->id,
            'prediction_type' => $predictionType,
            'prediction_label' => $this->predictionTypeLabel($predictionType),
            'winning_number' => $winningNumber,
            'winning_numbers' => [$winningNumber],
            'winner_count' => $winnerCount,
            'award_total' => $this->money($awardTotal),
            'announced_at' => $result->published_at?->toISOString() ?? $result->updated_at?->toISOString(),
            'customer' => null,
        ];

        if ($customerId === null || trim($customerId) === '') {
            return $summary;
        }

        $entries = TenantActivityEntry::query()
            ->forTenant((string) $row->tenant_id)
            ->where('activity_id', $row->id)
            ->where('customer_id', $customerId)
            ->where('prediction_type', $predictionType)
            ->where('status', '!=', 'cancelled')
            ->orderBy('created_at')
            ->get(['id', 'selected_number', 'status'])
            ->all();
        $winningEntries = array_values(array_filter(
            $entries,
            fn (object $entry): bool => (string) $entry->status === 'won'
        ));
        $processedEntries = array_values(array_filter(
            $entries,
            fn (object $entry): bool => in_array((string) $entry->status, ['won', 'lost'], true)
        ));
        $customerAwardTotal = (int) TenantActivityAward::query()
            ->forTenant((string) $row->tenant_id)
            ->where('activity_id', $row->id)
            ->where('customer_id', $customerId)
            ->where('type', 'lucky_board')
            ->where('prediction_type', $predictionType)
            ->sum('amount');

        $summary['customer'] = [
            'status' => $winningEntries !== []
                ? 'won'
                : ($processedEntries !== [] ? 'lost' : ($entries !== [] ? 'pending' : 'not_joined')),
            'entries_count' => count($entries),
            'processed_entries_count' => count($processedEntries),
            'winning_entries_count' => count($winningEntries),
            'selected_numbers' => array_map(fn (object $entry): string => (string) $entry->selected_number, $entries),
            'winning_numbers' => array_map(fn (object $entry): string => (string) $entry->selected_number, $winningEntries),
            'award_amount' => $this->money($customerAwardTotal),
        ];

        return $summary;
    }

    /**
     * @param array<int, string> $predictionTypes
     * @return array<string, array<int, string>>
     */
    private function reservedLuckyNumbersByPredictionType(string $tenantId, string $activityId, array $predictionTypes): array
    {
        if ($predictionTypes === []) {
            return [];
        }

        $rows = TenantActivityEntry::query()
            ->forTenant($tenantId)
            ->where('activity_id', $activityId)
            ->whereIn('prediction_type', $predictionTypes)
            ->where('status', '!=', 'cancelled')
            ->select(['prediction_type', 'selected_number'])
            ->distinct()
            ->orderBy('prediction_type')
            ->orderBy('selected_number')
            ->get()
            ->all();
        $reserved = [];

        foreach ($rows as $row) {
            $predictionType = (string) $row->prediction_type;
            $digits = $predictionType === 'first_prize_last3' ? 3 : 2;
            $number = preg_replace('/\D+/', '', (string) $row->selected_number) ?? '';

            if ($number === '') {
                continue;
            }

            $reserved[$predictionType][] = str_pad($number, $digits, '0', STR_PAD_LEFT);
        }

        foreach ($reserved as $predictionType => $numbers) {
            $numbers = array_values(array_unique($numbers));
            sort($numbers, SORT_STRING);
            $reserved[$predictionType] = $numbers;
        }

        return $reserved;
    }

    /**
     * @return array<string, mixed>
     */
    private function configResource(object $row): array
    {
        if ((string) $row->type === 'cashback') {
            $config = $row->relationLoaded('cashbackConfig') ? $row->cashbackConfig : null;
            $minimumType = $this->cashbackMinimumTypeFromConfig($config);

            return [
                'cashback_type' => (string) ($config?->cashback_type ?? 'percent'),
                'cashback_percent_bps' => (int) ($config?->cashback_percent_bps ?? 0),
                'fixed_amount' => $this->money((int) ($config?->fixed_amount ?? 0)),
                'minimum_type' => $minimumType,
                'min_ticket_count' => $minimumType === 'tickets' ? (int) ($config?->min_ticket_count ?? 0) : 0,
                'min_purchase_amount' => $this->money($minimumType === 'amount' ? (int) ($config?->min_purchase_amount ?? 0) : 0),
                'currency' => (string) ($config?->currency ?? 'THB'),
            ];
        }

        $config = $row->relationLoaded('luckyConfig') ? $row->luckyConfig : null;
        $predictionType = $this->selectedPredictionTypeFromConfig($config);

        return [
            'prediction_type' => $predictionType,
            'prediction_types' => [
                'first_prize_last2' => $predictionType === 'first_prize_last2',
                'first_prize_last3' => $predictionType === 'first_prize_last3',
                'last2' => $predictionType === 'last2',
            ],
            'eligibility_rule' => (string) ($config?->eligibility_rule ?? 'cumulative_tickets'),
            'threshold_tickets' => (int) ($config?->threshold_tickets ?? 1),
            'prizes' => [
                'first_prize_last2' => $this->money((int) ($config?->first_prize_last2_amount ?? 0)),
                'first_prize_last3' => $this->money((int) ($config?->first_prize_last3_amount ?? 0)),
                'last2' => $this->money((int) ($config?->last2_amount ?? 0)),
            ],
            'currency' => (string) ($config?->currency ?? 'THB'),
        ];
    }

    private function activityDescription(object $row): string
    {
        $locale = $this->canonicalLocale(app()->getLocale()) ?? 'th-TH';

        if ($locale === 'en-US') {
            return (string) $row->type === 'cashback'
                ? 'Cashback activity for eligible customers who do not win any prize.'
                : 'Lucky board activity. Pick your favorite number using rights earned from purchases.';
        }

        return (string) $row->type === 'cashback'
            ? 'กิจกรรมรับเงินคืนสำหรับลูกค้าที่เข้าเงื่อนไขและไม่ถูกรางวัล'
            : 'กิจกรรมแผงเลขนำโชค เลือกเลขที่ชอบตามสิทธิ์จากยอดซื้อ';
    }

    /**
     * @return array<string, mixed>
     */
    private function entryResource(?object $entry): array
    {
        if ($entry === null) {
            return [];
        }

        $customer = $entry->relationLoaded('customer') ? $entry->customer : null;

        return [
            'id' => (string) $entry->id,
            'tenant_id' => (string) $entry->tenant_id,
            'activity_id' => (string) $entry->activity_id,
            'game_id' => (string) $entry->game_id,
            'customer_id' => (string) $entry->customer_id,
            'customer' => $customer === null ? null : [
                'id' => (string) $customer->id,
                'name' => $customer->name ?? null,
                'phone' => $customer->phone ?? null,
            ],
            'prediction_type' => (string) $entry->prediction_type,
            'selected_number' => (string) $entry->selected_number,
            'status' => (string) $entry->status,
            'rights_rule' => $entry->rights_rule,
            'awarded_at' => $entry->awarded_at?->toISOString(),
            'created_at' => $entry->created_at?->toISOString(),
            'updated_at' => $entry->updated_at?->toISOString(),
        ];
    }

    /**
     * @return array<string, mixed>
     */
    private function awardResource(?object $award, bool $includeClaim = false): array
    {
        if ($award === null) {
            return [];
        }

        $activity = $award->relationLoaded('activity') ? $award->activity : null;
        $claim = $award->relationLoaded('claim') ? $award->claim : null;

        return [
            'id' => (string) $award->id,
            'tenant_id' => (string) $award->tenant_id,
            'activity_id' => (string) $award->activity_id,
            'game_id' => (string) $award->game_id,
            'customer_id' => (string) $award->customer_id,
            'entry_id' => $award->entry_id,
            'type' => (string) $award->type,
            'prediction_type' => $award->prediction_type,
            'activity_name' => $activity?->name,
            'amount' => $this->money((int) $award->amount, (string) $award->currency),
            'status' => (string) $award->status,
            'claim' => $includeClaim && $claim !== null ? $this->claimResource($claim) : null,
            'metadata' => $award->metadata_json ?? [],
            'calculated_at' => $award->calculated_at?->toISOString(),
            'created_at' => $award->created_at?->toISOString(),
            'updated_at' => $award->updated_at?->toISOString(),
        ];
    }

    /**
     * @return array<string, mixed>
     */
    private function claimResource(?object $claim): array
    {
        if ($claim === null) {
            return [];
        }

        $activity = $claim->relationLoaded('activity') ? $claim->activity : null;
        $award = $claim->relationLoaded('award') ? $claim->award : null;
        $customer = $claim->relationLoaded('customer') ? $claim->customer : null;

        return [
            'id' => (string) $claim->id,
            'tenant_id' => (string) $claim->tenant_id,
            'activity_award_id' => (string) $claim->activity_award_id,
            'activity_id' => (string) $claim->activity_id,
            'activity_name' => $activity?->name,
            'game_id' => (string) $claim->game_id,
            'customer_id' => (string) $claim->customer_id,
            'customer' => $customer === null ? null : [
                'id' => (string) $customer->id,
                'name' => $customer->name ?? null,
                'phone' => $customer->phone ?? null,
            ],
            'reference' => $claim->reference,
            'status' => (string) $claim->status,
            'payout_method' => (string) $claim->payout_method,
            'claim_amount' => $this->money((int) $claim->claim_amount, (string) $claim->currency),
            'amount' => $this->money((int) $claim->claim_amount, (string) $claim->currency),
            'bank_account' => $this->decodeJsonObject($claim->bank_account_json),
            'award' => $award === null ? null : $this->awardResource($award),
            'customer_note' => $claim->customer_note,
            'admin_note' => $claim->admin_note,
            'submitted_at' => $claim->submitted_at?->toISOString(),
            'reviewed_at' => $claim->reviewed_at?->toISOString(),
            'paid_at' => $claim->paid_at?->toISOString(),
            'created_at' => $claim->created_at?->toISOString(),
            'updated_at' => $claim->updated_at?->toISOString(),
        ];
    }

    private function normalizeSlug(string $value): string
    {
        $slug = Str::slug(trim($value), '-', 'th');

        if ($slug === '') {
            $slug = strtolower(preg_replace('/[^A-Za-z0-9]+/', '-', trim($value)) ?: '');
            $slug = trim($slug, '-');
        }

        return substr($slug !== '' ? $slug : 'activity-'.Str::lower(Str::random(8)), 0, 180);
    }

    private function generateActivitySlug(object $tenant): string
    {
        $prefix = $this->normalizeSlug((string) ($tenant->partner?->code ?? $tenant->partner_id ?? $tenant->code ?? 'partner'));
        $prefix = substr($prefix !== '' ? $prefix : 'partner', 0, 32);

        for ($attempt = 0; $attempt < 30; $attempt++) {
            $slug = $prefix.'-'.Str::lower(Str::random(5));

            if (! TenantActivity::query()->forTenant((string) $tenant->id)->where('slug', $slug)->exists()) {
                return $slug;
            }
        }

        return $prefix.'-'.Str::lower(substr(Str::ulid()->toBase32(), -8));
    }

    private function activityResultAt(mixed $drawAt): ?Carbon
    {
        if ($drawAt === null || trim((string) $drawAt) === '') {
            return null;
        }

        return Carbon::parse($drawAt)
            ->timezone('Asia/Bangkok')
            ->setTime(17, 0, 0);
    }

    private function boolValue(mixed $value): bool
    {
        return filter_var($value, FILTER_VALIDATE_BOOL, FILTER_NULL_ON_FAILURE) ?? false;
    }

    private function intValue(mixed $value): int
    {
        $int = filter_var($value, FILTER_VALIDATE_INT);

        return $int === false ? 0 : (int) $int;
    }

    private function minorAmount(mixed $value): int
    {
        if (is_array($value) && array_key_exists('amount', $value)) {
            return max(0, (int) $value['amount']);
        }

        return max(0, (int) round((float) $value));
    }

    /**
     * @return array{amount: int, currency: string}
     */
    private function money(int $amount, string $currency = 'THB'): array
    {
        return ['amount' => $amount, 'currency' => $currency];
    }

    /**
     * @param array<string, mixed> $entry
     * @return array<string, mixed>
     */
    private function lineActivityEntryVariables(string $tenantId, object $activity, array $entry): array
    {
        $customer = Customer::query()
            ->where('tenant_id', $tenantId)
            ->where('id', $entry['customer_id'] ?? '')
            ->first();

        return [
            'event' => ['title' => 'เข้าร่วมกิจกรรมสำเร็จ'],
            'tenant' => ['name' => (string) (PartnerTenant::query()->where('id', $tenantId)->value('name') ?: 'Partner')],
            'customer' => [
                'name' => (string) ($customer?->name ?? ''),
                'phone' => (string) ($customer?->phone ?? ''),
            ],
            'activity' => [
                'name' => (string) ($activity->name ?? ''),
                'selected_number' => (string) ($entry['selected_number'] ?? ''),
                'prediction_type' => $this->predictionTypeLabel((string) ($entry['prediction_type'] ?? '')),
            ],
        ];
    }

    /**
     * @param array<string, mixed> $claim
     * @return array<string, mixed>
     */
    private function lineActivityClaimVariables(string $tenantId, array $claim, string $statusLabel): array
    {
        $customer = is_array($claim['customer'] ?? null) ? $claim['customer'] : [];
        $amount = $claim['claim_amount']['amount'] ?? $claim['amount']['amount'] ?? 0;
        $reason = trim((string) ($claim['admin_note'] ?? ''));

        return [
            'event' => ['title' => 'แจ้งเตือนเงินกิจกรรม'],
            'tenant' => ['name' => (string) (PartnerTenant::query()->where('id', $tenantId)->value('name') ?: 'Partner')],
            'customer' => [
                'name' => (string) ($customer['name'] ?? ''),
                'phone' => (string) ($customer['phone'] ?? ''),
            ],
            'claim' => [
                'reference' => (string) ($claim['reference'] ?? $claim['id'] ?? ''),
                'amount_baht' => number_format(((int) $amount) / 100, 2),
                'status_label' => $statusLabel,
                'reason' => $reason === '' ? '' : 'เหตุผล: '.$reason,
            ],
        ];
    }

    /**
     * @param array<string, mixed> $claim
     * @return array<string, mixed>
     */
    private function telegramActivityClaimVariables(string $tenantId, array $claim, string $statusLabel, ?array $adminUser = null): array
    {
        $customer = is_array($claim['customer'] ?? null) ? $claim['customer'] : [];
        $amount = (int) ($claim['claim_amount']['amount'] ?? $claim['amount']['amount'] ?? 0);
        $reason = trim((string) ($claim['admin_note'] ?? ''));

        return [
            'event' => [
                'title' => 'ตรวจสอบรายการขึ้นเงินรางวัลกิจกรรมแล้ว',
                'occurred_at' => $this->telegramNotifications->occurredAt($claim['paid_at'] ?? $claim['reviewed_at'] ?? $claim['updated_at'] ?? null),
            ],
            'tenant' => ['name' => $this->telegramNotifications->tenantName($tenantId)],
            'admin' => $this->telegramNotifications->adminVariables($adminUser),
            'customer' => [
                'name' => (string) ($customer['name'] ?? ''),
                'phone' => (string) ($customer['phone'] ?? ''),
            ],
            'claim' => [
                'reference' => (string) ($claim['reference'] ?? $claim['id'] ?? ''),
                'amount_baht' => $this->telegramNotifications->baht($amount),
                'status_label' => $statusLabel,
                'reason' => $reason === '' ? '' : 'เหตุผล: '.$reason,
            ],
        ];
    }

    /**
     * @param array<string, mixed> $entry
     * @return array<string, mixed>
     */
    private function telegramActivityEntryVariables(string $tenantId, string $customerId, object $activity, array $entry): array
    {
        return [
            'event' => [
                'title' => 'ลูกค้าเข้าร่วมกิจกรรม',
                'occurred_at' => $this->telegramNotifications->occurredAt($entry['created_at'] ?? null),
            ],
            'tenant' => ['name' => $this->telegramNotifications->tenantName($tenantId)],
            'customer' => $this->telegramNotifications->customerVariables($tenantId, $customerId),
            'activity' => [
                'name' => (string) ($activity->name ?? ''),
                'prediction_type_label' => $this->predictionTypeLabel((string) ($entry['prediction_type'] ?? '')),
                'selected_number' => (string) ($entry['selected_number'] ?? ''),
                'rights_used' => '1 สิทธิ์',
            ],
        ];
    }

    private function predictionTypeLabel(string $type): string
    {
        if (($this->canonicalLocale(app()->getLocale()) ?? 'th-TH') === 'en-US') {
            return match ($type) {
                'first_prize_last2' => 'Guess 2 digits from first prize',
                'first_prize_last3' => 'Guess 3 digits from first prize',
                'last2' => 'Guess last 2 digits',
                default => $type,
            };
        }

        return match ($type) {
            'first_prize_last2' => '2 ตัวท้ายรางวัลที่ 1',
            'first_prize_last3' => '3 ตัวท้ายรางวัลที่ 1',
            'last2' => 'เลขท้าย 2 ตัว',
            default => $type,
        };
    }

    /**
     * @return array<string, string>
     */
    private function normalizeBankAccount(mixed $value): array
    {
        if (! is_array($value)) {
            return [];
        }

        $normalized = [
            'bank_name' => trim((string) ($value['bank_name'] ?? $value['bank'] ?? '')),
            'account_name' => trim((string) ($value['account_name'] ?? $value['bank_deposit_name'] ?? '')),
            'account_number' => trim((string) ($value['account_number'] ?? $value['account_no'] ?? $value['bank_account_no'] ?? $value['bank_deposit_number'] ?? '')),
            'branch' => trim((string) ($value['branch'] ?? '')),
        ];

        return array_filter($normalized, fn (string $field): bool => $field !== '');
    }

    /**
     * @param array<string, mixed> $bankAccount
     */
    private function hasUsableBankAccount(array $bankAccount): bool
    {
        return trim((string) ($bankAccount['bank_name'] ?? '')) !== ''
            && trim((string) ($bankAccount['account_number'] ?? '')) !== '';
    }

    /**
     * @return array<string, mixed>
     */
    private function customerRewardPayoutBankAccount(string $tenantId, string $customerId): array
    {
        $json = Customer::query()
            ->where('tenant_id', $tenantId)
            ->where('id', $customerId)
            ->value('reward_payout_bank_account_json');

        return $this->decodeJsonObject($json);
    }

    /**
     * @param array<string, mixed> $bankAccount
     */
    private function storeCustomerRewardPayoutBankAccount(string $tenantId, string $customerId, array $bankAccount): void
    {
        Customer::query()
            ->where('tenant_id', $tenantId)
            ->where('id', $customerId)
            ->update([
                'reward_payout_bank_account_json' => $bankAccount === [] ? null : json_encode($bankAccount, JSON_THROW_ON_ERROR),
                'updated_at' => now(),
            ]);
    }

    /**
     * @return array<string, mixed>
     */
    private function decodeJsonObject(mixed $json): array
    {
        if (is_array($json)) {
            return $json;
        }

        if ($json === null || $json === '') {
            return [];
        }

        $decoded = json_decode((string) $json, true);

        return is_array($decoded) ? $decoded : [];
    }

    private function limit(mixed $value): int
    {
        $limit = filter_var($value, FILTER_VALIDATE_INT);

        return $limit === false ? 20 : max(1, min(100, $limit));
    }

    /**
     * @param mixed $value
     * @return array<string, string>
     */
    private function normalizedLocalizedText(mixed $value): array
    {
        if (is_string($value) && trim($value) !== '') {
            $decoded = json_decode($value, true);
            $value = is_array($decoded) ? $decoded : [];
        }

        if (! is_array($value)) {
            return [];
        }

        $normalized = [];

        foreach ($value as $locale => $text) {
            $canonicalLocale = $this->canonicalLocale($locale);
            $string = trim((string) $text);

            if ($canonicalLocale !== null && $string !== '') {
                $normalized[$canonicalLocale] = $string;
            }
        }

        return $normalized;
    }

    /**
     * @param mixed $value
     * @return array<string, string>
     */
    private function decodedLocalizedText(mixed $value): array
    {
        return $this->normalizedLocalizedText($value);
    }

    private function localizedText(mixed $localized, mixed $fallback): ?string
    {
        $translations = $this->normalizedLocalizedText($localized);
        $locale = $this->canonicalLocale(app()->getLocale()) ?? 'th-TH';
        $fallbackText = trim((string) $fallback);

        return $translations[$locale]
            ?? $translations['th-TH']
            ?? ($fallbackText !== '' ? $fallbackText : null);
    }

    private function canonicalLocale(mixed $value): ?string
    {
        $locale = str_replace('_', '-', strtolower(trim((string) $value)));

        return match ($locale) {
            'th', 'th-th' => 'th-TH',
            'en', 'en-us', 'en-gb' => 'en-US',
            default => null,
        };
    }

    /**
     * @param array<string, mixed> $payload
     */
    private function audit(
        AdminSessionContext $actor,
        Request $request,
        string $action,
        string $targetId,
        array $payload,
        string $tenantId,
        ?string $partnerId,
    ): void {
        $this->auditLogger->logAdminWrite(
            actorId: $actor->adminUser['id'],
            scopeType: 'tenant',
            action: $action,
            targetType: 'tenant_activity',
            targetId: $targetId,
            payload: [
                'payload' => $payload,
                'idempotency_key' => $request->header('Idempotency-Key'),
            ],
            tenantId: $tenantId,
            partnerId: $partnerId,
            requestId: $request->header('X-Request-Id'),
            ipAddress: $request->ip(),
            userAgent: $request->userAgent(),
        );
    }
}
