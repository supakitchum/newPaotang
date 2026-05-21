<?php

namespace App\Console\Commands;

use App\Models\AdminAuthSession;
use App\Models\AdminPermissionCacheVersion;
use App\Models\AdminScope;
use App\Models\AdminUser;
use App\Models\AdminUserRole;
use App\Models\Customer;
use App\Models\CustomerAuthSession;
use App\Models\Game;
use App\Models\LocalStockItem;
use App\Models\Partner;
use App\Models\PartnerApiClient;
use App\Models\PartnerStockAllocation;
use App\Models\PartnerStockAllocationItem;
use App\Models\PartnerTenant;
use App\Models\PartnerTenantDomain;
use App\Models\Permission;
use App\Models\RewardCheckBatch;
use App\Models\RewardPrize;
use App\Models\RewardPublishLog;
use App\Models\RewardResult;
use App\Models\Role;
use App\Models\RolePermission;
use App\Models\StockItem;
use App\Models\StockReservation;
use App\Models\StockReservationItem;
use App\Models\Wallet;
use App\Models\WalletLedger;
use App\Modules\Reward\Services\ThaiGovernmentLotteryRewardTemplate;
use Database\Seeders\DefaultRbacMenuSeeder;
use Illuminate\Console\Command;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Hash;
use Illuminate\Support\Str;

class PrepareK6BaselineCommand extends Command
{
    private const DEFAULT_BASE_URL = 'http://host.docker.internal:8000';
    private const DEFAULT_TENANT_HOST = 'alpha.newpaotang.test';
    private const DEFAULT_STOCK_COUNT = 40;

    protected $signature = 'load-tests:k6:prepare
        {--output-json= : Write machine-readable fixture JSON to this path}
        {--output-env= : Write k6 env-file output to this path}
        {--base-url=http://host.docker.internal:8000 : API base URL used by k6 Docker runners}
        {--tenant-host=alpha.newpaotang.test : Tenant host used by customer/public scenarios}
        {--stock-count=40 : Available tenant-local stock rows to prepare}';

    protected $description = 'Prepare local/dev M10 k6 fixtures, bearer tokens, and machine-readable env artifacts.';

    public function handle(): int
    {
        if (app()->environment('production')) {
            $this->error('Refusing to create k6 load-test fixtures in production.');

            return self::FAILURE;
        }

        $outputJson = $this->pathOption('output-json', storage_path('app/load-tests/k6-baseline-env.json'));
        $outputEnv = $this->pathOption('output-env', storage_path('app/load-tests/k6-baseline.env'));
        $baseUrl = trim((string) ($this->option('base-url') ?: self::DEFAULT_BASE_URL));
        $tenantHost = strtolower(trim((string) ($this->option('tenant-host') ?: self::DEFAULT_TENANT_HOST)));
        $stockCount = max(4, min(500, (int) $this->option('stock-count')));

        $fixture = DB::transaction(fn (): array => $this->prepareFixture($baseUrl, $tenantHost, $stockCount));

        $this->writeJson($outputJson, $fixture);
        $this->writeEnv($outputEnv, $fixture['env']);

        $this->line('Prepared M10 k6 baseline fixtures.');
        $this->line('fixture_json: '.$outputJson);
        $this->line('fixture_env: '.$outputEnv);
        $this->line('tenant_id: '.$fixture['fixture']['tenant_id']);
        $this->line('partner_id: '.$fixture['fixture']['partner_id']);
        $this->line('game_id: '.$fixture['env']['GAME_ID']);
        $this->line('reward_result_id: '.$fixture['env']['REWARD_RESULT_ID']);

        return self::SUCCESS;
    }

    /**
     * @return array<string, mixed>
     */
    private function prepareFixture(string $baseUrl, string $tenantHost, int $stockCount): array
    {
        $now = now();
        $runId = strtolower(substr((string) Str::ulid(), -10));
        $tenant = $this->ensureTenantForHost($tenantHost);
        $admin = $this->ensureCentralAdmin();
        $stock = $this->createStockWorld($tenant['tenant_id'], $tenant['partner_id'], $runId, $stockCount, $now);
        $customer = $this->createCustomerWorld($tenant['tenant_id'], $stock['game_id'], $stock['checkout_local_stock_item_id'], $runId, $now);
        $reward = $this->createRewardWorld($admin['admin_user_id'], $runId, $now);
        $tokens = $this->issueTokens($tenant['tenant_id'], $tenant['partner_id'], $admin['admin_user_id'], $admin['scope_id'], $customer['customer_id'], $runId);

        $env = [
            'BASE_URL' => $baseUrl,
            'TENANT_HOST' => $tenantHost,
            'TENANT_ID' => $tenant['tenant_id'],
            'PARTNER_ID' => $tenant['partner_id'],
            'GAME_ID' => $stock['game_id'],
            'REWARD_GAME_ID' => $reward['game_id'],
            'SEARCH_NUMBER' => $stock['search_number'],
            'LOCAL_STOCK_ITEM_ID' => $stock['booking_local_stock_item_id'],
            'RESERVATION_ID' => $customer['reservation_id'],
            'CUSTOMER_TOKEN' => $tokens['customer_token'],
            'ADMIN_TOKEN' => $tokens['admin_token'],
            'PARTNER_TOKEN' => $tokens['partner_token'],
            'PARTNER_SYNC_PATH' => '/api/v1/partner-sync/events',
            'REWARD_RESULT_ID' => $reward['reward_result_id'],
            'CDN_BASE_URL' => '',
            'IMAGE_PATH' => '',
        ];

        return [
            'generated_at' => $now->toISOString(),
            'profile' => [
                'default_k6_profile' => 'smoke',
                'available_k6_profiles' => ['smoke', 'baseline', 'release-candidate'],
            ],
            'env' => $env,
            'fixture' => [
                'run_id' => $runId,
                'tenant_id' => $tenant['tenant_id'],
                'partner_id' => $tenant['partner_id'],
                'customer_id' => $customer['customer_id'],
                'wallet_id' => $customer['wallet_id'],
                'stock_allocation_id' => $stock['allocation_id'],
                'reward_result_id' => $reward['reward_result_id'],
                'ticket_image_cdn' => [
                    'available' => false,
                    'reason' => 'Local/dev fixture does not provision Cloudflare CDN/R2 ticket images. Set CDN_BASE_URL and IMAGE_PATH to run ticket-image-cdn-spike.js against a real CDN/object path.',
                ],
            ],
        ];
    }

    /**
     * @return array{partner_id: string, tenant_id: string}
     */
    private function ensureTenantForHost(string $tenantHost): array
    {
        $domain = PartnerTenantDomain::query()->where('host', $tenantHost)->first();
        $now = now();

        if ($domain !== null) {
            Partner::query()->where('id', $domain->partner_id)->update([
                'status' => 'active',
                'updated_at' => $now,
            ]);
            PartnerTenant::query()->where('id', $domain->tenant_id)->update([
                'status' => 'active',
                'updated_at' => $now,
            ]);
            PartnerTenantDomain::query()->where('id', $domain->id)->update([
                'status' => 'active',
                'verified_at' => $domain->verified_at ?? $now,
                'ssl_ready_at' => $domain->ssl_ready_at ?? $now,
                'updated_at' => $now,
            ]);

            return [
                'partner_id' => (string) $domain->partner_id,
                'tenant_id' => (string) $domain->tenant_id,
            ];
        }

        $partnerId = 'par_k6_baseline';
        $tenantId = 'ten_k6_baseline';

        Partner::query()->updateOrCreate(
            ['id' => $partnerId],
            [
                'code' => 'k6_baseline',
                'name' => 'K6 Baseline Partner',
                'type' => 'partner_store',
                'status' => 'active',
                'created_at' => $now,
                'updated_at' => $now,
            ],
        );

        PartnerTenant::query()->updateOrCreate(
            ['id' => $tenantId],
            [
                'partner_id' => $partnerId,
                'code' => 'k6_baseline',
                'name' => 'K6 Baseline Tenant',
                'status' => 'active',
                'created_at' => $now,
                'updated_at' => $now,
            ],
        );

        PartnerTenantDomain::query()->updateOrCreate(
            ['host' => $tenantHost],
            [
                'id' => 'dom_'.substr(sha1($tenantHost), 0, 20),
                'partner_id' => $partnerId,
                'tenant_id' => $tenantId,
                'type' => 'subdomain',
                'status' => 'active',
                'is_primary' => true,
                'verified_at' => $now,
                'ssl_ready_at' => $now,
                'created_at' => $now,
                'updated_at' => $now,
            ],
        );

        return [
            'partner_id' => $partnerId,
            'tenant_id' => $tenantId,
        ];
    }

    /**
     * @return array{admin_user_id: string, scope_id: string}
     */
    private function ensureCentralAdmin(): array
    {
        app(DefaultRbacMenuSeeder::class)->run();

        $now = now();
        $adminId = 'adm_k6_central';
        $scopeId = 'scp_k6_central';
        $roleId = 'rol_k6_central';

        AdminUser::query()->updateOrCreate(
            ['id' => $adminId],
            [
                'name' => 'K6 Central Admin',
                'email' => 'k6-central@newpaotang.test',
                'phone' => null,
                'password_hash' => Hash::make(Str::random(40)),
                'status' => 'active',
                'two_factor_enabled' => false,
                'created_at' => $now,
                'updated_at' => $now,
            ],
        );

        AdminScope::query()->updateOrCreate(
            ['id' => $scopeId],
            [
                'scope_type' => 'central',
                'tenant_id' => null,
                'partner_id' => null,
                'created_at' => $now,
                'updated_at' => $now,
            ],
        );

        Role::query()->updateOrCreate(
            ['id' => $roleId],
            [
                'scope_type' => 'central',
                'tenant_id' => null,
                'code' => 'k6_baseline',
                'name' => 'K6 Baseline',
                'status' => 'active',
                'version' => 1,
                'created_at' => $now,
                'updated_at' => $now,
            ],
        );

        AdminUserRole::query()->insertOrIgnore([[
            'admin_user_id' => $adminId,
            'role_id' => $roleId,
            'scope_id' => $scopeId,
            'created_at' => $now,
            'updated_at' => $now,
        ]]);

        $permissionIds = Permission::query()
            ->where('scope_type', 'central')
            ->whereIn('code', ['reward.view', 'reward.audit', 'partner.api.manage', 'stock.allocate'])
            ->pluck('id')
            ->all();

        RolePermission::query()->insertOrIgnore(array_map(fn (string $permissionId): array => [
            'role_id' => $roleId,
            'permission_id' => $permissionId,
            'created_at' => $now,
            'updated_at' => $now,
        ], $permissionIds));

        AdminPermissionCacheVersion::query()->updateOrCreate(
            ['admin_user_id' => $adminId, 'scope_id' => $scopeId],
            [
                'id' => 'pcv_k6_central',
                'version' => 1,
                'created_at' => $now,
                'updated_at' => $now,
            ],
        );

        return [
            'admin_user_id' => $adminId,
            'scope_id' => $scopeId,
        ];
    }

    /**
     * @return array{admin_token: string, customer_token: string, partner_token: string}
     */
    private function issueTokens(string $tenantId, string $partnerId, string $adminId, string $scopeId, string $customerId, string $runId): array
    {
        $now = now();
        $adminToken = 'npa_at_'.Str::random(64);
        $adminRefreshToken = 'npa_rt_'.Str::random(64);
        $customerToken = 'npa_ct_'.Str::random(64);
        $customerRefreshToken = 'npa_crt_'.Str::random(64);
        $partnerToken = 'npa_pt_'.Str::random(64);

        AdminAuthSession::query()->insert([
            'id' => 'ads_k6_'.$runId,
            'admin_user_id' => $adminId,
            'access_token_hash' => hash('sha256', $adminToken),
            'refresh_token_hash' => hash('sha256', $adminRefreshToken),
            'scope_type' => 'central',
            'scope_id' => $scopeId,
            'tenant_id' => null,
            'access_expires_at' => $now->copy()->addHours(6),
            'refresh_expires_at' => $now->copy()->addDays(7),
            'revoked_at' => null,
            'refreshed_from_id' => null,
            'last_used_at' => null,
            'created_at' => $now,
            'updated_at' => $now,
        ]);

        CustomerAuthSession::query()->insert([
            'id' => 'cas_k6_'.$runId,
            'tenant_id' => $tenantId,
            'customer_id' => $customerId,
            'access_token_hash' => hash('sha256', $customerToken),
            'refresh_token_hash' => hash('sha256', $customerRefreshToken),
            'access_expires_at' => $now->copy()->addHours(6),
            'refresh_expires_at' => $now->copy()->addDays(7),
            'revoked_at' => null,
            'refreshed_from_id' => null,
            'last_used_at' => null,
            'created_at' => $now,
            'updated_at' => $now,
        ]);

        PartnerApiClient::query()->insert([
            'id' => 'pac_k6_'.$runId,
            'partner_id' => $partnerId,
            'name' => 'K6 baseline '.$runId,
            'client_key' => 'pk_k6_'.$runId,
            'secret_hash' => hash('sha256', $partnerToken),
            'status' => 'active',
            'scopes_json' => json_encode(['partner-sync'], JSON_THROW_ON_ERROR),
            'last_used_at' => null,
            'revoked_at' => null,
            'created_at' => $now,
            'updated_at' => $now,
        ]);

        return [
            'admin_token' => $adminToken,
            'customer_token' => $customerToken,
            'partner_token' => $partnerToken,
        ];
    }

    /**
     * @return array{game_id: string, allocation_id: string, search_number: string, booking_local_stock_item_id: string, checkout_local_stock_item_id: string}
     */
    private function createStockWorld(string $tenantId, string $partnerId, string $runId, int $stockCount, mixed $now): array
    {
        $gameId = 'gam_k6_'.$runId;
        $allocationId = 'aln_k6_'.$runId;

        Game::query()->insert([
            'id' => $gameId,
            'code' => $gameId,
            'name' => 'K6 Baseline Game '.$runId,
            'sale_start_at' => $now->copy()->subMinute(),
            'draw_at' => $now->copy()->addDay(),
            'close_at' => $now->copy()->addHours(20),
            'closed_at' => null,
            'archived_at' => null,
            'status' => 'open',
            'metadata_json' => json_encode(['source' => 'k6_baseline'], JSON_THROW_ON_ERROR),
            'created_at' => $now,
            'updated_at' => $now,
        ]);

        $baseRows = [];
        for ($offset = 0; $offset < $stockCount; $offset++) {
            $fullNumber = str_pad((string) (100000 + $offset), 6, '0', STR_PAD_LEFT);
            $baseRows[] = [
                'full_number' => $fullNumber,
                'front3' => substr($fullNumber, 0, 3),
                'back3' => substr($fullNumber, -3),
                'back2' => substr($fullNumber, -2),
                'created_at' => $now,
                'updated_at' => $now,
            ];
        }
        DB::table('base_lottery_numbers')->insertOrIgnore($baseRows);

        DB::table('stock_supply_profiles')->insert([
            'id' => 'vsp_'.$gameId,
            'game_id' => $gameId,
            'status' => 'active',
            'seed' => 'k6-virtual-'.$runId,
            'base_count' => $stockCount,
            'total_capacity' => $stockCount,
            'set_distribution_json' => json_encode([], JSON_THROW_ON_ERROR),
            'created_by_admin_id' => null,
            'created_at' => $now,
            'updated_at' => $now,
        ]);

        PartnerStockAllocation::query()->insert([
            'id' => $allocationId,
            'partner_id' => $partnerId,
            'tenant_id' => $tenantId,
            'game_id' => $gameId,
            'quota_id' => null,
            'status' => 'allocated',
            'requested_count' => $stockCount,
            'allocation_percent_basis_points' => 10000,
            'allocated_count' => $stockCount,
            'idempotency_key' => 'k6-allocation-'.$runId,
            'supply_layer_ids_json' => json_encode(['vsp_'.$gameId], JSON_THROW_ON_ERROR),
            'created_by_admin_id' => null,
            'reason' => 'K6 local/dev baseline fixture',
            'cancelled_at' => null,
            'created_at' => $now,
            'updated_at' => $now,
        ]);

        $stockRows = [];
        $allocationRows = [];
        $localRows = [];

        for ($offset = 0; $offset < $stockCount; $offset++) {
            $fullNumber = str_pad((string) (100000 + $offset), 6, '0', STR_PAD_LEFT);
            $stockItemId = 'stk_k6_'.$runId.'_'.str_pad((string) $offset, 3, '0', STR_PAD_LEFT);
            $localStockItemId = 'lsi_k6_'.$runId.'_'.str_pad((string) $offset, 3, '0', STR_PAD_LEFT);
            $virtualStockRef = 'vstock:'.$tenantId.':'.$gameId.':'.$fullNumber.':0';

            $stockRows[] = [
                'id' => $stockItemId,
                'game_id' => $gameId,
                'batch_id' => null,
                'full_number' => $fullNumber,
                'front3' => substr($fullNumber, 0, 3),
                'back3' => substr($fullNumber, -3),
                'back2' => substr($fullNumber, -2),
                'status' => 'allocated',
                'partner_id' => $partnerId,
                'tenant_id' => $tenantId,
                'allocation_id' => $allocationId,
                'virtual_stock_ref' => $virtualStockRef,
                'virtual_copy_index' => 0,
                'recall_reason' => null,
                'recalled_at' => null,
                'created_at' => $now,
                'updated_at' => $now,
            ];

            $allocationRows[] = [
                'allocation_id' => $allocationId,
                'stock_item_id' => $stockItemId,
                'partner_id' => $partnerId,
                'tenant_id' => $tenantId,
                'game_id' => $gameId,
                'status' => 'allocated',
                'created_at' => $now,
                'updated_at' => $now,
            ];

            $localRows[] = [
                'id' => $localStockItemId,
                'tenant_id' => $tenantId,
                'partner_id' => $partnerId,
                'store_id' => null,
                'game_id' => $gameId,
                'stock_item_id' => $stockItemId,
                'allocation_id' => $allocationId,
                'full_number' => $fullNumber,
                'front3' => substr($fullNumber, 0, 3),
                'back3' => substr($fullNumber, -3),
                'back2' => substr($fullNumber, -2),
                'virtual_stock_ref' => $virtualStockRef,
                'virtual_copy_index' => 0,
                'image_url' => null,
                'image_thumb_url' => null,
                'status' => $offset === 1 ? 'reserved' : 'available',
                'synced_at' => $now,
                'reserved_at' => $offset === 1 ? $now : null,
                'sold_at' => null,
                'created_at' => $now,
                'updated_at' => $now,
            ];
        }

        StockItem::query()->insert($stockRows);
        PartnerStockAllocationItem::query()->insert($allocationRows);
        LocalStockItem::query()->insert($localRows);

        return [
            'game_id' => $gameId,
            'allocation_id' => $allocationId,
            'search_number' => '100000',
            'booking_local_stock_item_id' => 'lsi_k6_'.$runId.'_000',
            'checkout_local_stock_item_id' => 'lsi_k6_'.$runId.'_001',
        ];
    }

    /**
     * @return array{customer_id: string, wallet_id: string, reservation_id: string}
     */
    private function createCustomerWorld(string $tenantId, string $gameId, string $checkoutLocalStockItemId, string $runId, mixed $now): array
    {
        $customerId = 'cus_k6_'.$runId;
        $walletId = 'wal_k6_'.$runId;
        $reservationId = 'res_k6_'.$runId;
        $phone = '089'.substr(str_pad((string) abs(crc32($runId)), 10, '0', STR_PAD_LEFT), 0, 7);

        Customer::query()->insert([
            'id' => $customerId,
            'tenant_id' => $tenantId,
            'phone' => $phone,
            'email' => $customerId.'@load-test.local',
            'password_hash' => Hash::make(Str::random(32)),
            'avatar_url' => null,
            'name' => 'K6 Baseline Customer',
            'status' => 'active',
            'last_login_at' => $now,
            'created_at' => $now,
            'updated_at' => $now,
        ]);

        Wallet::query()->insert([
            'id' => $walletId,
            'tenant_id' => $tenantId,
            'customer_id' => $customerId,
            'name' => 'K6 primary wallet',
            'type' => 'primary',
            'status' => 'active',
            'balance_amount' => 10000000,
            'currency' => 'THB',
            'created_at' => $now,
            'updated_at' => $now,
        ]);

        WalletLedger::query()->insert([
            'id' => 'wle_k6_'.$runId,
            'tenant_id' => $tenantId,
            'wallet_id' => $walletId,
            'customer_id' => $customerId,
            'entry_type' => 'credit',
            'status' => 'posted',
            'amount' => 10000000,
            'currency' => 'THB',
            'balance_after' => 10000000,
            'reference_type' => 'k6_fixture',
            'reference_id' => $reservationId,
            'idempotency_key' => 'k6-wallet-'.$runId,
            'created_by_admin_id' => null,
            'metadata_json' => json_encode(['source' => 'load-tests:k6:prepare'], JSON_THROW_ON_ERROR),
            'posted_at' => $now,
            'created_at' => $now,
            'updated_at' => $now,
        ]);

        StockReservation::query()->insert([
            'id' => $reservationId,
            'tenant_id' => $tenantId,
            'customer_id' => $customerId,
            'game_id' => $gameId,
            'status' => 'active',
            'expires_at' => $now->copy()->addHours(2),
            'released_at' => null,
            'cancelled_at' => null,
            'converted_at' => null,
            'idempotency_key' => 'k6-checkout-reservation-'.$runId,
            'payload_hash' => hash('sha256', $gameId.':'.$checkoutLocalStockItemId),
            'released_idempotency_key' => null,
            'released_payload_hash' => null,
            'cancelled_idempotency_key' => null,
            'cancelled_payload_hash' => null,
            'cancelled_by_admin_id' => null,
            'cancel_reason' => null,
            'created_at' => $now,
            'updated_at' => $now,
        ]);

        StockReservationItem::query()->insert([
            'reservation_id' => $reservationId,
            'local_stock_item_id' => $checkoutLocalStockItemId,
            'tenant_id' => $tenantId,
            'game_id' => $gameId,
            'status' => 'active',
            'created_at' => $now,
            'updated_at' => $now,
        ]);

        return [
            'customer_id' => $customerId,
            'wallet_id' => $walletId,
            'reservation_id' => $reservationId,
        ];
    }

    /**
     * @return array{game_id: string, reward_result_id: string}
     */
    private function createRewardWorld(string $adminId, string $runId, mixed $now): array
    {
        $gameId = 'gmr_k6_'.$runId;
        $rewardResultId = 'rew_k6_'.$runId;
        $prizes = $this->thaiGovernmentLotteryPrizes('100000');
        $summary = [
            'game_id' => $gameId,
            'reward_version' => 1,
            'status' => 'published',
            'prizes' => array_map(fn (array $prize): array => $prize + [
                'winning_count' => 0,
                'total_amount' => ['amount' => 0, 'currency' => 'THB'],
            ], $prizes),
            'winning_count' => 0,
            'checked_ticket_count' => 0,
        ];

        Game::query()->insert([
            'id' => $gameId,
            'code' => $gameId,
            'name' => 'K6 Reward Game '.$runId,
            'sale_start_at' => $now->copy()->subDay(),
            'draw_at' => $now->copy()->subHour(),
            'close_at' => $now->copy()->subHours(2),
            'closed_at' => $now->copy()->subHours(2),
            'archived_at' => null,
            'status' => 'reward_published',
            'metadata_json' => json_encode(['source' => 'k6_baseline_reward'], JSON_THROW_ON_ERROR),
            'created_at' => $now,
            'updated_at' => $now,
        ]);

        RewardResult::query()->insert([
            'id' => $rewardResultId,
            'game_id' => $gameId,
            'status' => 'published',
            'version' => 1,
            'summary_json' => json_encode($summary, JSON_THROW_ON_ERROR),
            'created_by_admin_id' => $adminId,
            'verified_by_admin_id' => $adminId,
            'published_by_admin_id' => $adminId,
            'corrected_by_admin_id' => null,
            'correction_note' => null,
            'checked_at' => $now,
            'verified_at' => $now,
            'published_at' => $now,
            'corrected_at' => null,
            'created_at' => $now,
            'updated_at' => $now,
        ]);

        RewardPrize::query()->insert(array_map(fn (array $prize, int $index): array => [
            'id' => 'rpr_'.substr(sha1($rewardResultId.':'.$index), 0, 20),
            'reward_result_id' => $rewardResultId,
            'game_id' => $gameId,
            'prize_type' => $prize['prize_type'],
            'prize_number' => $prize['prize_number'],
            'amount' => $prize['amount']['amount'],
            'currency' => $prize['amount']['currency'],
            'sort_order' => $index,
            'created_at' => $now,
            'updated_at' => $now,
        ], $prizes, array_keys($prizes)));

        RewardCheckBatch::query()->insert([
            'id' => 'rcb_k6_'.$runId,
            'reward_result_id' => $rewardResultId,
            'game_id' => $gameId,
            'status' => 'completed',
            'chunk_count' => 0,
            'processed_ticket_count' => 0,
            'winning_count' => 0,
            'idempotency_key' => 'k6-reward-check-'.$runId,
            'payload_hash' => hash('sha256', $rewardResultId),
            'started_at' => $now,
            'completed_at' => $now,
            'created_at' => $now,
            'updated_at' => $now,
        ]);

        RewardPublishLog::query()->insert([
            'id' => 'rpl_k6_'.$runId,
            'reward_result_id' => $rewardResultId,
            'game_id' => $gameId,
            'reward_version' => 1,
            'published_by_admin_id' => $adminId,
            'payload_json' => json_encode($summary, JSON_THROW_ON_ERROR),
            'published_at' => $now,
            'created_at' => $now,
            'updated_at' => $now,
        ]);

        return [
            'game_id' => $gameId,
            'reward_result_id' => $rewardResultId,
        ];
    }

    /**
     * @return array<int, array{prize_type: string, prize_number: string, amount: array{amount: int, currency: string}}>
     */
    private function thaiGovernmentLotteryPrizes(string $firstPrizeNumber): array
    {
        $rows = [];

        foreach (ThaiGovernmentLotteryRewardTemplate::rules() as $type => $rule) {
            for ($index = 1; $index <= $rule['count']; $index++) {
                $rows[] = [
                    'prize_type' => $type,
                    'prize_number' => $type === 'first_prize'
                        ? $firstPrizeNumber
                        : str_pad((string) $index, $rule['digits'], '0', STR_PAD_LEFT),
                    'amount' => [
                        'amount' => $rule['amount'],
                        'currency' => ThaiGovernmentLotteryRewardTemplate::CURRENCY,
                    ],
                ];
            }
        }

        return $rows;
    }

    private function pathOption(string $name, string $fallback): string
    {
        $value = trim((string) ($this->option($name) ?? ''));

        return $value === '' ? $fallback : $value;
    }

    /**
     * @param array<string, mixed> $payload
     */
    private function writeJson(string $path, array $payload): void
    {
        $this->ensureDirectory(dirname($path));
        file_put_contents($path, json_encode($payload, JSON_PRETTY_PRINT | JSON_UNESCAPED_SLASHES).PHP_EOL);
    }

    /**
     * @param array<string, string> $env
     */
    private function writeEnv(string $path, array $env): void
    {
        $this->ensureDirectory(dirname($path));
        $lines = [];

        foreach ($env as $key => $value) {
            $lines[] = $key.'='.$value;
        }

        file_put_contents($path, implode(PHP_EOL, $lines).PHP_EOL);
    }

    private function ensureDirectory(string $path): void
    {
        if (! is_dir($path)) {
            mkdir($path, 0775, true);
        }
    }
}
