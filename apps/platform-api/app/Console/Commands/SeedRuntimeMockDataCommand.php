<?php

namespace App\Console\Commands;

use Carbon\CarbonImmutable;
use Illuminate\Console\Command;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Hash;
use Illuminate\Support\Facades\Schema;
use Throwable;

class SeedRuntimeMockDataCommand extends Command
{
    private const CURRENCY = 'THB';
    private const TICKET_PRICE_AMOUNT = 8000;
    private const SAMPLE_SOURCE = 'runtime_dashboard_seed';
    private const SAMPLE_CUSTOMER_LIMIT = 50000;
    private const SAMPLE_AFFILIATE_LIMIT = 300;
    private const FIRST_NAMES = [
        'กิตติ', 'วรินทร์', 'ณัฐพล', 'ศิริพร', 'ปวีณา', 'ธนกร', 'อรทัย', 'ภัทร', 'จิราพร', 'สุชาติ',
        'มนัสวี', 'ธิดารัตน์', 'อาทิตย์', 'วรรณา', 'พรชัย', 'พิมพ์ชนก', 'นพดล', 'ชุติมา', 'สาธิต', 'รัตนา',
        'ปกรณ์', 'กมลวรรณ', 'อารีย์', 'วิชัย', 'จารุวรรณ', 'ปิยะ', 'ดวงพร', 'ธีรภัทร', 'นลินี', 'ศุภชัย',
    ];
    private const LAST_NAMES = [
        'แสงทอง', 'สุขใจ', 'จันทร์ดี', 'มีทรัพย์', 'รุ่งเรือง', 'บุญมา', 'ศรีสวัสดิ์', 'แก้วอินทร์', 'ทองสุข', 'ปัญญาดี',
        'อินทร์ประเสริฐ', 'ลาภเจริญ', 'ขจรศักดิ์', 'สุวรรณรักษ์', 'เกียรติไพบูลย์', 'ตั้งมั่น', 'ร่มเย็น', 'วงศ์วัฒนา', 'ปรีชากุล', 'ทรัพย์อนันต์',
    ];
    private const BANKS = [
        ['name' => 'ธนาคารกรุงไทย', 'prefix' => '006', 'branch' => 'สาขาอโศก'],
        ['name' => 'ธนาคารไทยพาณิชย์', 'prefix' => '014', 'branch' => 'สาขาสยามพารากอน'],
        ['name' => 'ธนาคารกสิกรไทย', 'prefix' => '004', 'branch' => 'สาขาลาดพร้าว'],
        ['name' => 'G Wallet', 'prefix' => '006', 'branch' => 'G Wallet'],
    ];

    protected $signature = 'runtime:mock-data:seed
        {--ticket-count=10000 : Number of sold ticket/order datasets to seed}
        {--tickets-per-game= : Comma-separated sold ticket counts per selected game, oldest draw first}
        {--partners=3 : Number of existing active partners/tenants to use}
        {--games=2 : Number of existing games to use, newest draw first}
        {--chunk=500 : Bulk upsert chunk size}
        {--reset-mock : Delete earlier generated sample rows before seeding}
        {--reset-sample : Delete generated sample rows before seeding}';

    protected $description = 'Seed local/runtime sample commerce, wallet, reward, affiliate, and monitor data for existing partners and games.';

    /** @var array<string, array<int, string>> */
    private array $columns = [];

    /** @var array<string, array<int, array<string, mixed>>> */
    private array $pending = [];

    /** @var array<string, object> */
    private array $rewardResultsByGame = [];

    /** @var array<string, array<int, object>> */
    private array $rewardPrizesByGame = [];

    /** @var array<string, array<int, string>> */
    private array $winnerSeedNumbersByGame = [];

    /** @var array<string, array<string, int>> */
    private array $gameStats = [];

    /** @var array<string, array<string, int>> */
    private array $tenantGameStats = [];

    /** @var array<string, array<int, string>> */
    private array $affiliateIdsByTenant = [];

    /** @var array<string, string> */
    private array $affiliateProgramIds = [];

    /** @var array<string, string> */
    private array $commissionRuleIds = [];

    private int $chunkSize = 500;

    public function handle(): int
    {
        if (app()->environment('production')) {
            $this->error('Refusing to seed runtime sample data in production.');

            return self::FAILURE;
        }

        $ticketCount = max(1, min(self::SAMPLE_CUSTOMER_LIMIT, (int) $this->option('ticket-count')));
        $partnerCount = max(1, (int) $this->option('partners'));
        $gameCount = max(1, (int) $this->option('games'));
        $this->chunkSize = max(100, min(2000, (int) $this->option('chunk')));

        DB::disableQueryLog();

        $pairs = $this->activePartnerTenantPairs($partnerCount);
        $games = $this->targetGames($gameCount);

        if (count($pairs) < $partnerCount) {
            $this->error("Expected {$partnerCount} active partner/tenant pairs, found ".count($pairs).'.');

            return self::FAILURE;
        }

        if (count($games) < $gameCount) {
            $this->error("Expected {$gameCount} existing games, found ".count($games).'.');

            return self::FAILURE;
        }

        $this->loadRewardData($games);
        try {
            $ticketGames = $this->ticketGameSequence($games, $ticketCount);
        } catch (\InvalidArgumentException $exception) {
            $this->error($exception->getMessage());

            return self::FAILURE;
        }
        $ticketCount = count($ticketGames);

        $summary = DB::transaction(function () use ($pairs, $games, $ticketGames): array {
            if ((bool) $this->option('reset-mock') || (bool) $this->option('reset-sample')) {
                $this->resetMockRows();
            }

            return $this->seedMockRows($pairs, $games, $ticketGames);
        });

        $this->newLine();
        $this->info('Seeded runtime sample data.');
        $this->line('partners: '.implode(', ', array_map(fn (object $row): string => "{$row->partner_code}/{$row->tenant_code}", $pairs)));
        $this->line('games: '.implode(', ', array_map(fn (object $row): string => "{$row->code} ({$row->id})", $games)));
        $this->table(['dataset', 'count'], collect($summary)->map(fn (int $count, string $key): array => [$key, number_format($count)])->values()->all());

        return self::SUCCESS;
    }

    /**
     * @return array<int, object>
     */
    private function activePartnerTenantPairs(int $limit): array
    {
        return DB::table('partners')
            ->join('partner_tenants', 'partner_tenants.partner_id', '=', 'partners.id')
            ->where('partners.status', 'active')
            ->where('partner_tenants.status', 'active')
            ->select([
                'partners.id as partner_id',
                'partners.code as partner_code',
                'partners.name as partner_name',
                'partner_tenants.id as tenant_id',
                'partner_tenants.code as tenant_code',
                'partner_tenants.name as tenant_name',
            ])
            ->orderBy('partners.created_at')
            ->orderBy('partners.id')
            ->limit($limit)
            ->get()
            ->all();
    }

    /**
     * @return array<int, object>
     */
    private function targetGames(int $limit): array
    {
        return DB::table('games')
            ->select(['id', 'code', 'name', 'status', 'sale_start_at', 'close_at', 'draw_at', 'created_at', 'updated_at'])
            ->orderByDesc('draw_at')
            ->orderByDesc('created_at')
            ->limit($limit)
            ->get()
            ->all();
    }

    /**
     * @param array<int, object> $games
     */
    private function loadRewardData(array $games): void
    {
        $gameIds = array_map(fn (object $game): string => (string) $game->id, $games);
        $this->rewardResultsByGame = DB::table('reward_results')
            ->whereIn('game_id', $gameIds)
            ->get()
            ->keyBy('game_id')
            ->all();

        $this->rewardPrizesByGame = DB::table('reward_prizes')
            ->whereIn('game_id', $gameIds)
            ->orderBy('sort_order')
            ->orderBy('id')
            ->get()
            ->groupBy('game_id')
            ->map(fn ($rows): array => $rows->all())
            ->all();

        foreach ($games as $game) {
            $gameId = (string) $game->id;
            $this->winnerSeedNumbersByGame[$gameId] = $this->winnerSeedNumbers($this->rewardPrizesByGame[$gameId] ?? []);
        }
    }

    /**
     * @param array<int, object> $pairs
     * @param array<int, object> $games
     * @param array<int, object> $ticketGames
     * @return array<string, int>
     */
    private function seedMockRows(array $pairs, array $games, array $ticketGames): array
    {
        $summary = [
            'customers' => 0,
            'orders' => 0,
            'tickets' => 0,
            'wallet_ledger' => 0,
            'public_visit_sessions' => 0,
            'customer_auth_sessions' => 0,
            'admin_auth_sessions' => 0,
            'affiliate_accounts' => 0,
            'affiliate_attributions' => 0,
            'commission_transactions' => 0,
            'winning_tickets' => 0,
            'reward_claims' => 0,
        ];

        $this->prepareTenantGrowthRows($pairs);

        $ticketCount = count($ticketGames);
        $affiliateLimit = min(self::SAMPLE_AFFILIATE_LIMIT, $ticketCount);
        $passwordHash = Hash::make('Password123!');
        $pinHash = Hash::make('123456');

        for ($index = 1; $index <= $ticketCount; $index++) {
            $pair = $this->weightedPick($pairs, [46, 34, 20]);
            $game = $ticketGames[$index - 1];
            $tenantId = (string) $pair->tenant_id;
            $partnerId = (string) $pair->partner_id;
            $gameId = (string) $game->id;

            $perGameIndex = ($this->gameStats[$gameId]['tickets'] ?? 0) + 1;
            $this->gameStats[$gameId]['tickets'] = $perGameIndex;

            $tenantGameKey = $tenantId.':'.$gameId;
            $this->tenantGameStats[$tenantGameKey]['tickets'] = ($this->tenantGameStats[$tenantGameKey]['tickets'] ?? 0) + 1;

            $fullNumber = $this->ticketNumber($index, $perGameIndex, $gameId);
            $front3 = substr($fullNumber, 0, 3);
            $back3 = substr($fullNumber, -3);
            $back2 = substr($fullNumber, -2);
            $paidAt = $this->paidAtFor($index, $game);
            $createdAt = $paidAt->subMinutes(7);
            $customerId = $this->mockId('cus', $index);
            $walletId = $this->mockId('wal', $index);
            $stockItemId = $this->mockId('stk', $index);
            $localStockItemId = $this->mockId('lsi', $index);
            $reservationId = $this->mockId('res', $index);
            $orderId = $this->mockId('ord', $index);
            $ticketId = $this->mockId('tck', $index);
            $topupId = $this->mockId('top', $index);
            $paymentId = $this->mockId('pay', $index);
            $topupAmount = $this->topupAmount($index);
            $walletBalance = $topupAmount - self::TICKET_PRICE_AMOUNT;
            [$firstName, $lastName, $customerName] = $this->customerName($index);
            $autoPayoutMethod = random_int(1, 100) <= 36 ? 'bank_transfer' : 'wallet_credit';
            $bankAccount = $this->bankAccount($index, $customerName);
            $paymentProvider = $this->paymentProvider($index);

            $winningRows = $this->winningRows($fullNumber, $gameId);
            $claimRow = null;
            $payoutLedgerRow = null;

            if ($winningRows !== []) {
                $claimStatus = $this->claimStatus($index);
                $claimId = $this->mockId('rcl', $index);
                $claimSubmittedAt = $paidAt->addMinutes(25);
                $claimAmount = array_sum(array_map(fn (array $row): int => (int) $row['amount'], $winningRows));
                $payoutMethod = $autoPayoutMethod;
                $payoutLedgerId = null;
                $paidAtValue = null;
                $reviewedAtValue = null;

                if ($claimStatus === 'approved') {
                    $reviewedAtValue = $claimSubmittedAt->addMinutes(45);
                    $paidAtValue = $reviewedAtValue->addMinutes(15);

                    if ($payoutMethod === 'wallet_credit') {
                        $payoutLedgerId = $this->mockId('wlp', $index);
                        $walletBalance += $claimAmount;
                        $payoutLedgerRow = [
                            'id' => $payoutLedgerId,
                            'tenant_id' => $tenantId,
                            'wallet_id' => $walletId,
                            'customer_id' => $customerId,
                            'entry_type' => 'credit',
                            'status' => 'posted',
                            'amount' => $claimAmount,
                            'currency' => self::CURRENCY,
                            'balance_after' => $walletBalance,
                            'reference_type' => 'reward_claim',
                            'reference_id' => $claimId,
                            'idempotency_key' => 'reward-payout-'.$index,
                            'metadata_json' => $this->json([
                                'source' => self::SAMPLE_SOURCE,
                                'ticket_id' => $ticketId,
                                'game_id' => $gameId,
                            ]),
                            'posted_at' => $this->date($paidAtValue),
                            'created_at' => $this->date($paidAtValue),
                            'updated_at' => $this->date($paidAtValue),
                        ];
                    }
                } elseif ($claimStatus === 'rejected') {
                    $reviewedAtValue = $claimSubmittedAt->addMinutes(50);
                }

                foreach ($winningRows as $rowIndex => $winnerRow) {
                    $winnerId = $this->mockId('win', $index, $rowIndex + 1);
                    $this->queue('winning_tickets', [
                        'id' => $winnerId,
                        'tenant_id' => $tenantId,
                        'game_id' => $gameId,
                        'ticket_id' => $ticketId,
                        'reward_result_id' => $winnerRow['reward_result_id'],
                        'reward_prize_id' => $winnerRow['reward_prize_id'],
                        'prize_type' => $winnerRow['prize_type'],
                        'prize_number' => $winnerRow['prize_number'],
                        'amount' => $winnerRow['amount'],
                        'base_amount' => $winnerRow['amount'],
                        'adjustment_amount' => 0,
                        'tenant_price_rule_id' => null,
                        'price_rule_snapshot_json' => $this->json([
                            'source' => 'central_reward',
                        ]),
                        'currency' => self::CURRENCY,
                        'status' => $claimStatus === 'approved' ? 'paid' : 'verified',
                        'created_at' => $this->date($claimSubmittedAt),
                        'updated_at' => $this->date($claimSubmittedAt),
                    ]);

                    if ($rowIndex === 0) {
                        $claimRow = [
                            'id' => $claimId,
                            'tenant_id' => $tenantId,
                            'customer_id' => $customerId,
                            'ticket_id' => $ticketId,
                            'winning_ticket_id' => $winnerId,
                            'game_id' => $gameId,
                            'wallet_id' => $walletId,
                            'payout_ledger_id' => $payoutLedgerId,
                            'reference' => 'RWD-'.$claimSubmittedAt->format('ymd').'-'.str_pad((string) $index, 5, '0', STR_PAD_LEFT),
                            'status' => $claimStatus,
                            'payout_method' => $payoutMethod,
                            'prize_amount' => $claimAmount,
                            'base_prize_amount' => $claimAmount,
                            'adjustment_amount' => 0,
                            'tenant_price_rule_id' => null,
                            'price_rule_snapshot_json' => $this->json([
                                'source' => self::SAMPLE_SOURCE,
                            ]),
                            'currency' => self::CURRENCY,
                            'bank_account_json' => $payoutMethod === 'bank_transfer' ? $this->json($bankAccount) : null,
                            'customer_note' => null,
                            'admin_note' => $claimStatus === 'rejected' ? 'ข้อมูลบัญชีรับเงินไม่ตรงกับข้อมูลลูกค้า' : null,
                            'idempotency_key' => 'reward-claim-'.$index,
                            'payload_hash' => hash('sha256', 'reward-claim-'.$index),
                            'reviewed_by_admin_id' => null,
                            'paid_by_admin_id' => null,
                            'submitted_at' => $this->date($claimSubmittedAt),
                            'reviewed_at' => $reviewedAtValue === null ? null : $this->date($reviewedAtValue),
                            'paid_at' => $paidAtValue === null ? null : $this->date($paidAtValue),
                            'created_at' => $this->date($claimSubmittedAt),
                            'updated_at' => $this->date($paidAtValue ?? $reviewedAtValue ?? $claimSubmittedAt),
                        ];
                    }
                }

                $this->gameStats[$gameId]['winning_rows'] = ($this->gameStats[$gameId]['winning_rows'] ?? 0) + count($winningRows);
                $this->gameStats[$gameId]['winning_tickets'] = ($this->gameStats[$gameId]['winning_tickets'] ?? 0) + 1;
                $this->tenantGameStats[$tenantGameKey]['winning_rows'] = ($this->tenantGameStats[$tenantGameKey]['winning_rows'] ?? 0) + count($winningRows);
            }

            $this->queue('customers', [
                'id' => $customerId,
                'tenant_id' => $tenantId,
                'customer_no' => 'C'.str_pad((string) $index, 9, '0', STR_PAD_LEFT),
                'phone' => $this->phoneNumber($index),
                'name' => $customerName,
                'first_name' => $firstName,
                'last_name' => $lastName,
                'status' => 'active',
                'email' => $this->emailAddress($index, $firstName, $lastName),
                'password_hash' => $passwordHash,
                'pin_hash' => $pinHash,
                'pin_set_at' => $this->date($createdAt),
                'pin_changed_at' => $this->date($createdAt),
                'pin_failed_attempts' => 0,
                'pin_locked_until' => null,
                'pin_last_verified_at' => $this->date($paidAt->subMinutes(1)),
                'avatar_url' => null,
                'last_login_at' => $this->date($paidAt->subMinutes(2)),
                'reward_payout_bank_account_json' => $this->json($bankAccount),
                'auto_reward_claim_enabled' => true,
                'auto_reward_claim_payout_method' => $autoPayoutMethod,
                'created_at' => $this->date($createdAt),
                'updated_at' => $this->date($paidAt),
            ]);

            $this->queue('wallets', [
                'id' => $walletId,
                'tenant_id' => $tenantId,
                'customer_id' => $customerId,
                'name' => 'Primary wallet',
                'type' => 'primary',
                'status' => 'active',
                'balance_amount' => $walletBalance,
                'currency' => self::CURRENCY,
                'created_at' => $this->date($createdAt),
                'updated_at' => $this->date($paidAt),
            ]);

            $this->queue('stock_items', [
                'id' => $stockItemId,
                'game_id' => $gameId,
                'batch_id' => null,
                'full_number' => $fullNumber,
                'front3' => $front3,
                'back3' => $back3,
                'back2' => $back2,
                'status' => 'sold',
                'partner_id' => $partnerId,
                'tenant_id' => $tenantId,
                'allocation_id' => null,
                'recall_reason' => null,
                'recalled_at' => null,
                'virtual_stock_ref' => 'rt-'.$gameId.'-'.$index,
                'virtual_copy_index' => $index,
                'created_at' => $this->date($createdAt),
                'updated_at' => $this->date($paidAt),
            ]);

            $this->queue('local_stock_items', [
                'id' => $localStockItemId,
                'tenant_id' => $tenantId,
                'partner_id' => $partnerId,
                'store_id' => 'store-'.str_pad((string) (($index % 6) + 1), 2, '0', STR_PAD_LEFT),
                'game_id' => $gameId,
                'stock_item_id' => $stockItemId,
                'allocation_id' => null,
                'full_number' => $fullNumber,
                'front3' => $front3,
                'back3' => $back3,
                'back2' => $back2,
                'image_url' => null,
                'image_thumb_url' => null,
                'status' => 'sold',
                'synced_at' => $this->date($createdAt),
                'reserved_at' => $this->date($paidAt->subMinutes(4)),
                'sold_at' => $this->date($paidAt),
                'created_at' => $this->date($createdAt),
                'updated_at' => $this->date($paidAt),
            ]);

            $this->queue('stock_reservations', [
                'id' => $reservationId,
                'tenant_id' => $tenantId,
                'customer_id' => $customerId,
                'game_id' => $gameId,
                'status' => 'converted',
                'expires_at' => $this->date($paidAt->addMinutes(15)),
                'released_at' => null,
                'cancelled_at' => null,
                'converted_at' => $this->date($paidAt),
                'idempotency_key' => 'reservation-'.$index,
                'payload_hash' => hash('sha256', 'reservation-'.$index),
                'created_at' => $this->date($paidAt->subMinutes(4)),
                'updated_at' => $this->date($paidAt),
            ]);

            $this->queue('stock_reservation_items', [
                'reservation_id' => $reservationId,
                'local_stock_item_id' => $localStockItemId,
                'tenant_id' => $tenantId,
                'game_id' => $gameId,
                'status' => 'converted',
                'price_amount' => self::TICKET_PRICE_AMOUNT,
                'currency' => self::CURRENCY,
                'sale_price_rule_snapshot_json' => $this->json([
                    'source' => self::SAMPLE_SOURCE,
                    'ticket_price_amount' => self::TICKET_PRICE_AMOUNT,
                    'currency' => self::CURRENCY,
                ]),
                'created_at' => $this->date($paidAt->subMinutes(4)),
                'updated_at' => $this->date($paidAt),
            ]);

            $this->queue('orders', [
                'id' => $orderId,
                'tenant_id' => $tenantId,
                'customer_id' => $customerId,
                'reservation_id' => $reservationId,
                'game_id' => $gameId,
                'wallet_id' => $walletId,
                'payment_method' => $paymentProvider,
                'status' => 'paid',
                'payment_status' => 'paid',
                'total_amount' => self::TICKET_PRICE_AMOUNT,
                'currency' => self::CURRENCY,
                'reference' => 'ORD-'.$paidAt->format('ymd').'-'.str_pad((string) $index, 5, '0', STR_PAD_LEFT),
                'admin_note' => null,
                'idempotency_key' => 'order-'.$index,
                'payload_hash' => hash('sha256', 'order-'.$index),
                'paid_at' => $this->date($paidAt),
                'cancelled_at' => null,
                'refunded_at' => null,
                'created_at' => $this->date($paidAt->subMinutes(3)),
                'updated_at' => $this->date($paidAt),
            ]);

            $this->queue('tickets', [
                'id' => $ticketId,
                'tenant_id' => $tenantId,
                'customer_id' => $customerId,
                'order_id' => $orderId,
                'local_stock_item_id' => $localStockItemId,
                'game_id' => $gameId,
                'full_number' => $fullNumber,
                'status' => $this->ticketStatus($winningRows, $claimRow),
                'image_url' => null,
                'image_thumb_url' => null,
                'image_render_snapshot_json' => $this->json([
                    'source' => self::SAMPLE_SOURCE,
                    'partner_id' => $partnerId,
                    'tenant_id' => $tenantId,
                    'game_id' => $gameId,
                    'full_number' => $fullNumber,
                ]),
                'created_at' => $this->date($paidAt),
                'updated_at' => $this->date($paidAt),
            ]);

            $this->queue('order_items', [
                'id' => $this->mockId('oit', $index),
                'tenant_id' => $tenantId,
                'order_id' => $orderId,
                'local_stock_item_id' => $localStockItemId,
                'ticket_id' => $ticketId,
                'status' => 'fulfilled',
                'price_amount' => self::TICKET_PRICE_AMOUNT,
                'currency' => self::CURRENCY,
                'created_at' => $this->date($paidAt),
                'updated_at' => $this->date($paidAt),
            ]);

            $this->queue('topup_requests', [
                'id' => $topupId,
                'tenant_id' => $tenantId,
                'customer_id' => $customerId,
                'wallet_id' => $walletId,
                'payment_id' => null,
                'provider' => 'manual',
                'channel' => $this->topupChannel($index),
                'status' => 'succeeded',
                'amount' => $topupAmount,
                'bonus_amount' => 0,
                'currency' => self::CURRENCY,
                'reference' => 'TOP-'.$paidAt->format('ymd').'-'.str_pad((string) $index, 5, '0', STR_PAD_LEFT),
                'transfer_at' => $this->date($paidAt->subHours(2)),
                'slip_url' => null,
                'idempotency_key' => 'topup-'.$index,
                'payload_hash' => hash('sha256', 'topup-'.$index),
                'reviewed_by_admin_id' => null,
                'reviewed_at' => $this->date($paidAt->subHours(2)->addMinutes(5)),
                'admin_note' => 'ตรวจสอบยอดเติมเงินสำเร็จ',
                'provider_payload_json' => $this->json(['source' => self::SAMPLE_SOURCE]),
                'created_at' => $this->date($paidAt->subHours(2)),
                'updated_at' => $this->date($paidAt->subHours(2)->addMinutes(5)),
            ]);

            $this->queue('payments', [
                'id' => $paymentId,
                'tenant_id' => $tenantId,
                'customer_id' => $customerId,
                'order_id' => $orderId,
                'topup_request_id' => null,
                'provider' => $paymentProvider,
                'status' => 'succeeded',
                'amount' => self::TICKET_PRICE_AMOUNT,
                'currency' => self::CURRENCY,
                'reference' => 'PAY-'.$paidAt->format('ymd').'-'.str_pad((string) $index, 5, '0', STR_PAD_LEFT),
                'redirect_url' => null,
                'idempotency_key' => 'payment-'.$index,
                'payload_hash' => hash('sha256', 'payment-'.$index),
                'provider_event_id' => 'evt-'.$paidAt->format('ymd').'-'.$index,
                'provider_reference' => 'provider-'.$paidAt->format('ymd').'-'.$index,
                'provider_payload_json' => $this->json(['source' => self::SAMPLE_SOURCE]),
                'paid_at' => $this->date($paidAt),
                'created_at' => $this->date($paidAt->subMinutes(2)),
                'updated_at' => $this->date($paidAt),
            ]);

            $this->queue('wallet_ledger', [
                'id' => $this->mockId('wlt', $index),
                'tenant_id' => $tenantId,
                'wallet_id' => $walletId,
                'customer_id' => $customerId,
                'entry_type' => 'credit',
                'status' => 'posted',
                'amount' => $topupAmount,
                'currency' => self::CURRENCY,
                'balance_after' => $topupAmount,
                'reference_type' => 'topup',
                'reference_id' => $topupId,
                'idempotency_key' => 'ledger-topup-'.$index,
                'metadata_json' => $this->json(['source' => self::SAMPLE_SOURCE]),
                'posted_at' => $this->date($paidAt->subHours(2)->addMinutes(5)),
                'created_at' => $this->date($paidAt->subHours(2)->addMinutes(5)),
                'updated_at' => $this->date($paidAt->subHours(2)->addMinutes(5)),
            ]);

            $this->queue('wallet_ledger', [
                'id' => $this->mockId('wld', $index),
                'tenant_id' => $tenantId,
                'wallet_id' => $walletId,
                'customer_id' => $customerId,
                'entry_type' => 'debit',
                'status' => 'posted',
                'amount' => self::TICKET_PRICE_AMOUNT,
                'currency' => self::CURRENCY,
                'balance_after' => $topupAmount - self::TICKET_PRICE_AMOUNT,
                'reference_type' => 'order',
                'reference_id' => $orderId,
                'idempotency_key' => 'ledger-purchase-'.$index,
                'metadata_json' => $this->json([
                    'source' => self::SAMPLE_SOURCE,
                    'full_number' => $fullNumber,
                ]),
                'posted_at' => $this->date($paidAt),
                'created_at' => $this->date($paidAt),
                'updated_at' => $this->date($paidAt),
            ]);

            if ($payoutLedgerRow !== null) {
                $this->queue('wallet_ledger', $payoutLedgerRow);
            }

            if ($claimRow !== null) {
                $this->queue('reward_claims', $claimRow);
            }

            if ($index <= $affiliateLimit) {
                $this->queueAffiliateAccountRows($index, $pair, $customerId, $createdAt);
                $summary['affiliate_accounts']++;
            }

            if ($index % 4 === 0) {
                $affiliateId = $this->affiliateForTenant($tenantId, $index);

                if ($affiliateId !== null) {
                    $this->queueAffiliateOrderRows($index, $pair, $customerId, $orderId, $affiliateId, $paidAt);
                    $summary['affiliate_attributions']++;
                    $summary['commission_transactions']++;
                }
            }

            if ($this->queuePublicVisitRows($index, $pair, $customerId, $paidAt)) {
                $summary['public_visit_sessions']++;
            }

            if ($this->queueCustomerAuthSessionRows($index, $pair, $customerId, $paidAt)) {
                $summary['customer_auth_sessions']++;
            }

            $summary['customers']++;
            $summary['orders']++;
            $summary['tickets']++;
            $summary['wallet_ledger'] += $payoutLedgerRow === null ? 2 : 3;
            $summary['winning_tickets'] += count($winningRows);
            $summary['reward_claims'] += $claimRow === null ? 0 : 1;

            if ($this->pendingCount('customers') >= $this->chunkSize) {
                $this->flushPending();
            }
        }

        $summary['admin_auth_sessions'] = $this->queueAdminAuthSessionRows($pairs);

        $this->flushPending();
        $this->finalizeRewardCheckRows($games);
        $summary['virtual_stock_counters'] = $this->rebuildVirtualStockCounters($games);

        return $summary;
    }

    /**
     * @param array<int, object> $pairs
     */
    private function prepareTenantGrowthRows(array $pairs): void
    {
        foreach ($pairs as $tenantIndex => $pair) {
            $tenantId = (string) $pair->tenant_id;
            $programId = $this->mockId('afp', $tenantIndex + 1);
            $ruleId = $this->mockId('cmr', $tenantIndex + 1);
            $this->affiliateProgramIds[$tenantId] = $programId;
            $this->commissionRuleIds[$tenantId] = $ruleId;
            $now = CarbonImmutable::now();

            $this->queue('affiliate_programs', [
                'id' => $programId,
                'tenant_id' => $tenantId,
                'code' => 'partner-affiliate-network',
                'name' => 'Partner Affiliate Network',
                'status' => 'active',
                'starts_at' => $this->date($now->subMonths(2)),
                'ends_at' => null,
                'metadata_json' => $this->json(['source' => self::SAMPLE_SOURCE]),
                'created_by_admin_id' => null,
                'created_at' => $this->date($now->subMonths(2)),
                'updated_at' => $this->date($now),
            ]);

            $this->queue('commission_rules', [
                'id' => $ruleId,
                'tenant_id' => $tenantId,
                'affiliate_program_id' => $programId,
                'affiliate_account_id' => null,
                'code' => 'paid-order-standard',
                'name' => 'Standard paid-order commission',
                'rule_type' => 'fixed_per_order',
                'amount' => 500,
                'rate_bps' => 0,
                'currency' => self::CURRENCY,
                'status' => 'active',
                'metadata_json' => $this->json(['source' => self::SAMPLE_SOURCE]),
                'created_by_admin_id' => null,
                'created_at' => $this->date($now->subMonths(2)),
                'updated_at' => $this->date($now),
            ]);
        }
    }

    private function queueAffiliateAccountRows(int $index, object $pair, string $customerId, CarbonImmutable $createdAt): void
    {
        $tenantId = (string) $pair->tenant_id;
        $affiliateId = $this->mockId('aff', $index);
        $linkId = $this->mockId('afl', $index);
        $code = 'AGT'.str_pad((string) $index, 6, '0', STR_PAD_LEFT);
        [$firstName, $lastName, $affiliateName] = $this->customerName($index + 9000);
        $this->affiliateIdsByTenant[$tenantId][] = $affiliateId;

        $this->queue('affiliate_accounts', [
            'id' => $affiliateId,
            'tenant_id' => $tenantId,
            'customer_id' => $customerId,
            'code' => $code,
            'name' => $affiliateName,
            'phone' => $this->phoneNumber($index + 20000),
            'email' => $this->emailAddress($index + 20000, $firstName, $lastName),
            'status' => $index % 11 === 0 ? 'paused' : 'active',
            'wallet_balance_amount' => 50000 + (($index % 30) * 500),
            'currency' => self::CURRENCY,
            'payout_profile_json' => $this->json($this->bankAccount($index, $affiliateName)),
            'metadata_json' => $this->json(['source' => self::SAMPLE_SOURCE]),
            'created_by_admin_id' => null,
            'created_at' => $this->date($createdAt),
            'updated_at' => $this->date($createdAt),
        ]);

        $this->queue('affiliate_links', [
            'id' => $linkId,
            'tenant_id' => $tenantId,
            'affiliate_account_id' => $affiliateId,
            'affiliate_program_id' => $this->affiliateProgramIds[$tenantId] ?? null,
            'code' => strtolower($code),
            'url' => 'https://'.$pair->tenant_code.'.newpaotang.test/?ref='.strtolower($code),
            'status' => 'active',
            'metadata_json' => $this->json(['source' => self::SAMPLE_SOURCE]),
            'created_by_admin_id' => null,
            'created_at' => $this->date($createdAt),
            'updated_at' => $this->date($createdAt),
        ]);

        if ($index % 15 === 0) {
            $this->queue('affiliate_payouts', [
                'id' => $this->mockId('afpayout', $index),
                'tenant_id' => $tenantId,
                'affiliate_account_id' => $affiliateId,
                'status' => $index % 30 === 0 ? 'pending' : 'approved',
                'payout_method' => $index % 2 === 0 ? 'wallet_credit' : 'bank_transfer',
                'amount' => 25000 + (($index % 10) * 1000),
                'currency' => self::CURRENCY,
                'bank_account_json' => $this->json($this->bankAccount($index, $affiliateName)),
                'admin_note' => 'รอบจ่ายค่าคอมมิชชันประจำงวด',
                'idempotency_key' => 'affiliate-payout-'.$index,
                'payload_hash' => hash('sha256', 'affiliate-payout-'.$index),
                'requested_by_admin_id' => null,
                'approved_by_admin_id' => null,
                'approved_at' => $index % 30 === 0 ? null : $this->date($createdAt->addDays(1)),
                'created_at' => $this->date($createdAt),
                'updated_at' => $this->date($createdAt->addDays(1)),
            ]);
        }
    }

    private function queueAffiliateOrderRows(int $index, object $pair, string $customerId, string $orderId, string $affiliateId, CarbonImmutable $paidAt): void
    {
        $tenantId = (string) $pair->tenant_id;
        $attributionId = $this->mockId('atr', $index);
        $linkId = str_replace('aff_', 'afl_', $affiliateId);
        $ruleId = $this->commissionRuleIds[$tenantId] ?? null;

        if ($ruleId === null) {
            return;
        }

        $this->queue('affiliate_attributions', [
            'id' => $attributionId,
            'tenant_id' => $tenantId,
            'affiliate_account_id' => $affiliateId,
            'affiliate_link_id' => $linkId,
            'affiliate_program_id' => $this->affiliateProgramIds[$tenantId] ?? null,
            'customer_id' => $customerId,
            'order_id' => $orderId,
            'status' => 'converted',
            'attributed_at' => $this->date($paidAt->subDays(1)),
            'converted_at' => $this->date($paidAt),
            'metadata_json' => $this->json(['source' => self::SAMPLE_SOURCE]),
            'created_at' => $this->date($paidAt->subDays(1)),
            'updated_at' => $this->date($paidAt),
        ]);

        $this->queue('commission_transactions', [
            'id' => $this->mockId('com', $index),
            'tenant_id' => $tenantId,
            'affiliate_account_id' => $affiliateId,
            'affiliate_attribution_id' => $attributionId,
            'order_id' => $orderId,
            'commission_rule_id' => $ruleId,
            'original_commission_id' => null,
            'transaction_type' => 'commission',
            'status' => $index % 12 === 0 ? 'calculated' : 'approved',
            'amount' => 500,
            'currency' => self::CURRENCY,
            'idempotency_key' => 'commission-'.$index,
            'payload_hash' => hash('sha256', 'commission-'.$index),
            'calculated_at' => $this->date($paidAt),
            'approved_by_admin_id' => null,
            'approved_at' => $index % 12 === 0 ? null : $this->date($paidAt->addMinutes(10)),
            'metadata_json' => $this->json(['source' => self::SAMPLE_SOURCE]),
            'created_at' => $this->date($paidAt),
            'updated_at' => $this->date($paidAt->addMinutes(10)),
        ]);
    }

    private function queuePublicVisitRows(int $index, object $pair, string $customerId, CarbonImmutable $paidAt): bool
    {
        if (! Schema::hasTable('public_visit_sessions')) {
            return false;
        }

        $activeAt = $index <= 240
            ? CarbonImmutable::now()->subSeconds(($index * 7) % 840)
            : $paidAt;

        $this->queue('public_visit_sessions', [
            'id' => $this->mockId('pvs', $index),
            'tenant_id' => (string) $pair->tenant_id,
            'partner_id' => (string) $pair->partner_id,
            'customer_id' => $index % 5 === 0 ? null : $customerId,
            'visitor_key' => 'visitor-'.$index,
            'session_key' => 'session-'.$index,
            'source' => $this->visitSource($index),
            'channel' => $this->visitChannel($index),
            'path' => $this->visitPath($index),
            'referrer' => $index % 4 === 0 ? 'https://google.com/search?q=lottery' : null,
            'ip_address' => '10.'.($index % 200).'.'.(($index * 3) % 200).'.'.(($index * 7) % 200),
            'user_agent' => $this->userAgent($index),
            'screen' => $index % 3 === 0 ? '390x844' : '430x932',
            'timezone' => 'Asia/Bangkok',
            'first_seen_at' => $this->date($activeAt->subMinutes(12)),
            'last_seen_at' => $this->date($activeAt),
            'expires_at' => $this->date($activeAt->addMinutes(30)),
            'metadata_json' => $this->json(['source' => self::SAMPLE_SOURCE]),
            'created_at' => $this->date($activeAt->subMinutes(12)),
            'updated_at' => $this->date($activeAt),
        ]);

        return true;
    }

    private function queueCustomerAuthSessionRows(int $index, object $pair, string $customerId, CarbonImmutable $paidAt): bool
    {
        if (! Schema::hasTable('customer_auth_sessions')) {
            return false;
        }

        $activeAt = $index <= 360
            ? CarbonImmutable::now()->subSeconds(($index * 11) % 840)
            : $paidAt->addMinutes($index % 90);

        $this->queue('customer_auth_sessions', [
            'id' => $this->mockId('cas', $index),
            'tenant_id' => (string) $pair->tenant_id,
            'customer_id' => $customerId,
            'access_token_hash' => hash('sha256', 'runtime-customer-access-'.$index),
            'refresh_token_hash' => hash('sha256', 'runtime-customer-refresh-'.$index),
            'access_expires_at' => $this->date($activeAt->addHours(8)),
            'refresh_expires_at' => $this->date($activeAt->addDays(30)),
            'revoked_at' => null,
            'refreshed_from_id' => null,
            'last_used_at' => $this->date($activeAt),
            'pin_verified_at' => $this->date($activeAt->subMinutes(2)),
            'created_at' => $this->date($activeAt->subMinutes(25)),
            'updated_at' => $this->date($activeAt),
        ]);

        return true;
    }

    /**
     * @param array<int, object> $pairs
     */
    private function queueAdminAuthSessionRows(array $pairs): int
    {
        if (! Schema::hasTable('admin_auth_sessions') || ! Schema::hasTable('admin_users') || ! Schema::hasTable('admin_scopes')) {
            return 0;
        }

        $assignments = Schema::hasTable('admin_user_roles')
            ? DB::table('admin_user_roles')
                ->join('admin_scopes', 'admin_scopes.id', '=', 'admin_user_roles.scope_id')
                ->select([
                    'admin_user_roles.admin_user_id',
                    'admin_user_roles.scope_id',
                    'admin_scopes.scope_type',
                    'admin_scopes.tenant_id',
                ])
                ->orderBy('admin_user_roles.created_at')
                ->limit(120)
                ->get()
            : collect();

        if ($assignments->isEmpty()) {
            $centralScopeId = DB::table('admin_scopes')
                ->where('scope_type', 'central')
                ->orderBy('id')
                ->value('id');

            $assignments = DB::table('admin_users')
                ->selectRaw('id as admin_user_id')
                ->orderBy('created_at')
                ->limit(30)
                ->get()
                ->map(fn (object $row): object => (object) [
                    'admin_user_id' => (string) $row->admin_user_id,
                    'scope_id' => $centralScopeId,
                    'scope_type' => 'central',
                    'tenant_id' => null,
                ]);
        }

        $count = 0;
        $now = CarbonImmutable::now();

        foreach ($assignments as $index => $assignment) {
            if (($assignment->scope_id ?? null) === null) {
                continue;
            }

            $number = $index + 1;
            $activeAt = $number <= 20
                ? $now->subSeconds(($number * 19) % 840)
                : $now->subDays($number % 14)->setTime(($number * 3) % 24, ($number * 7) % 60, 0);
            $tenantId = $assignment->tenant_id ?? null;

            if (($assignment->scope_type ?? 'central') === 'tenant' && $tenantId === null && $pairs !== []) {
                $tenantId = (string) $pairs[$number % count($pairs)]->tenant_id;
            }

            $this->queue('admin_auth_sessions', [
                'id' => $this->mockId('aas', $number),
                'admin_user_id' => (string) $assignment->admin_user_id,
                'access_token_hash' => hash('sha256', 'runtime-admin-access-'.$number),
                'refresh_token_hash' => hash('sha256', 'runtime-admin-refresh-'.$number),
                'scope_type' => (string) ($assignment->scope_type ?? 'central'),
                'scope_id' => (string) $assignment->scope_id,
                'tenant_id' => $tenantId,
                'access_expires_at' => $this->date($activeAt->addHours(8)),
                'refresh_expires_at' => $this->date($activeAt->addDays(30)),
                'revoked_at' => null,
                'refreshed_from_id' => null,
                'last_used_at' => $this->date($activeAt),
                'created_at' => $this->date($activeAt->subMinutes(45)),
                'updated_at' => $this->date($activeAt),
            ]);

            $count++;
        }

        return $count;
    }

    private function affiliateForTenant(string $tenantId, int $index): ?string
    {
        $affiliates = $this->affiliateIdsByTenant[$tenantId] ?? [];

        if ($affiliates === []) {
            return null;
        }

        return $affiliates[$index % count($affiliates)];
    }

    /**
     * @param array<int, object> $games
     */
    private function finalizeRewardCheckRows(array $games): void
    {
        $batchRows = [];
        $itemRows = [];
        $now = CarbonImmutable::now();

        foreach ($games as $gameIndex => $game) {
            $gameId = (string) $game->id;
            $rewardResult = $this->rewardResultsByGame[$gameId] ?? null;

            if ($rewardResult === null) {
                continue;
            }

            $processed = $this->gameStats[$gameId]['tickets'] ?? 0;
            $winningRows = $this->gameStats[$gameId]['winning_rows'] ?? 0;
            $batchId = $this->mockId('rcb', $gameIndex + 1);
            $batchRows[] = [
                'id' => $batchId,
                'reward_result_id' => (string) $rewardResult->id,
                'game_id' => $gameId,
                'status' => 'completed',
                'chunk_count' => max(1, (int) ceil($processed / $this->chunkSize)),
                'processed_ticket_count' => $processed,
                'winning_count' => $winningRows,
                'idempotency_key' => 'reward-check-'.$gameId,
                'payload_hash' => hash('sha256', 'reward-check-'.$gameId),
                'started_at' => $this->date($now->subMinutes(30)),
                'completed_at' => $this->date($now->subMinutes(20)),
                'created_at' => $this->date($now->subMinutes(30)),
                'updated_at' => $this->date($now->subMinutes(20)),
            ];

            foreach ($this->tenantGameStats as $tenantGameKey => $stats) {
                [$tenantId, $tenantGameId] = explode(':', $tenantGameKey, 2);

                if ($tenantGameId !== $gameId) {
                    continue;
                }

                $itemRows[] = [
                    'id' => $this->mockId('rci', count($itemRows) + 1),
                    'reward_check_batch_id' => $batchId,
                    'reward_result_id' => (string) $rewardResult->id,
                    'tenant_id' => $tenantId,
                    'cursor_from' => null,
                    'cursor_to' => null,
                    'status' => 'completed',
                    'checked_count' => $stats['tickets'] ?? 0,
                    'winning_count' => $stats['winning_rows'] ?? 0,
                    'created_at' => $this->date($now->subMinutes(30)),
                    'updated_at' => $this->date($now->subMinutes(20)),
                ];
            }
        }

        $this->upsertRows('reward_check_batches', $batchRows, ['id']);
        $this->upsertRows('reward_check_items', $itemRows, ['id']);
    }

    /**
     * @param array<int, object> $games
     */
    private function rebuildVirtualStockCounters(array $games): int
    {
        if (! Schema::hasTable('virtual_stock_counters') || ! Schema::hasTable('local_stock_items')) {
            return 0;
        }

        $gameIds = array_values(array_filter(array_map(fn (object $game): string => (string) $game->id, $games)));
        if ($gameIds === []) {
            return 0;
        }

        DB::table('virtual_stock_counters')->whereIn('game_id', $gameIds)->delete();

        $counters = [];
        $rows = DB::table('local_stock_items')
            ->whereIn('game_id', $gameIds)
            ->whereIn('status', ['reserved', 'sold'])
            ->get(['game_id', 'partner_id', 'full_number', 'front3', 'back3', 'back2', 'status']);

        foreach ($rows as $row) {
            $gameId = (string) $row->game_id;
            $partnerId = (string) ($row->partner_id ?? '');
            $fullNumber = (string) $row->full_number;
            $status = (string) $row->status;
            $dimensions = [
                ['full_number', $fullNumber],
                ['front3', (string) ($row->front3 ?? substr($fullNumber, 0, 3))],
                ['back3', (string) ($row->back3 ?? substr($fullNumber, -3))],
                ['back2', (string) ($row->back2 ?? substr($fullNumber, -2))],
            ];

            foreach ($dimensions as [$dimension, $value]) {
                $this->incrementCounterRow($counters, $gameId, 'central', 'central', $dimension, $value, $status);

                if ($partnerId !== '') {
                    $this->incrementCounterRow($counters, $gameId, 'partner', $partnerId, $dimension, $value, $status);
                }
            }
        }

        $this->upsertRows('virtual_stock_counters', array_values($counters), ['id']);

        return count($counters);
    }

    /**
     * @param array<string, array<string, mixed>> $counters
     */
    private function incrementCounterRow(array &$counters, string $gameId, string $scopeType, string $scopeId, string $dimension, string $value, string $status): void
    {
        if ($value === '') {
            return;
        }

        $key = $gameId.'|'.$scopeType.'|'.$scopeId.'|'.$dimension.'|'.$value;
        $now = $this->date(CarbonImmutable::now());

        if (! isset($counters[$key])) {
            $counters[$key] = [
                'id' => 'vsc_'.substr(sha1($key), 0, 36),
                'game_id' => $gameId,
                'scope_type' => $scopeType,
                'scope_id' => $scopeId,
                'dimension' => $dimension,
                'value' => $value,
                'reserved_count' => 0,
                'sold_count' => 0,
                'created_at' => $now,
                'updated_at' => $now,
            ];
        }

        if ($status === 'sold') {
            $counters[$key]['sold_count']++;
        } else {
            $counters[$key]['reserved_count']++;
        }

        $counters[$key]['updated_at'] = $now;
    }

    /**
     * @return array<int, array{reward_result_id: string, reward_prize_id: string, prize_type: string, prize_number: string, amount: int}>
     */
    private function winningRows(string $fullNumber, string $gameId): array
    {
        $rewardResult = $this->rewardResultsByGame[$gameId] ?? null;

        if ($rewardResult === null) {
            return [];
        }

        $rows = [];

        foreach ($this->rewardPrizesByGame[$gameId] ?? [] as $prize) {
            if (! $this->matchesPrize($fullNumber, (string) $prize->prize_number, (string) $prize->prize_type)) {
                continue;
            }

            $rows[] = [
                'reward_result_id' => (string) $rewardResult->id,
                'reward_prize_id' => (string) $prize->id,
                'prize_type' => (string) $prize->prize_type,
                'prize_number' => (string) $prize->prize_number,
                'amount' => (int) $prize->amount,
            ];
        }

        return $rows;
    }

    private function matchesPrize(string $fullNumber, string $prizeNumber, string $prizeType): bool
    {
        $normalized = strtolower(trim($prizeNumber));
        $type = strtolower($prizeType);

        if ($normalized === '') {
            return false;
        }

        if (str_contains($normalized, 'x')) {
            $pattern = '/^'.str_replace('x', '[0-9]', preg_quote($normalized, '/')).'$/';

            return preg_match($pattern, $fullNumber) === 1;
        }

        if (strlen($normalized) === 6) {
            return $fullNumber === $normalized;
        }

        if (strlen($normalized) === 3) {
            if (str_contains($type, 'front')) {
                return substr($fullNumber, 0, 3) === $normalized;
            }

            if (str_contains($type, 'back')) {
                return substr($fullNumber, -3) === $normalized;
            }

            return substr($fullNumber, 0, 3) === $normalized || substr($fullNumber, -3) === $normalized;
        }

        if (strlen($normalized) === 2) {
            return substr($fullNumber, -2) === $normalized;
        }

        return false;
    }

    /**
     * @param array<int, object> $prizes
     * @return array<int, string>
     */
    private function winnerSeedNumbers(array $prizes): array
    {
        $numbers = [];

        foreach ($prizes as $index => $prize) {
            $number = strtolower((string) $prize->prize_number);
            $type = strtolower((string) $prize->prize_type);

            if ($number === '') {
                continue;
            }

            if (str_contains($number, 'x')) {
                $numbers[] = substr(strtr($number, ['x' => (string) (($index + 3) % 10)]), 0, 6);
                continue;
            }

            if (strlen($number) === 6) {
                $numbers[] = $number;
                continue;
            }

            if (strlen($number) === 3) {
                $suffix = str_pad((string) (($index * 37) % 1000), 3, '0', STR_PAD_LEFT);
                $prefix = str_pad((string) (($index * 53) % 1000), 3, '0', STR_PAD_LEFT);
                $numbers[] = str_contains($type, 'front') ? $number.$suffix : $prefix.$number;
                continue;
            }

            if (strlen($number) === 2) {
                $numbers[] = str_pad((string) (($index * 97) % 10000), 4, '0', STR_PAD_LEFT).$number;
            }
        }

        return array_values(array_unique(array_filter($numbers, fn (string $number): bool => preg_match('/^\d{6}$/', $number) === 1)));
    }

    /**
     * @template T
     * @param array<int, T> $rows
     * @param array<int, int> $weights
     * @return T
     */
    private function weightedPick(array $rows, array $weights): mixed
    {
        $count = count($rows);
        $effectiveWeights = array_slice($weights, 0, $count);

        while (count($effectiveWeights) < $count) {
            $effectiveWeights[] = 10;
        }

        $total = max(1, array_sum($effectiveWeights));
        $roll = random_int(1, $total);
        $cursor = 0;

        foreach ($rows as $index => $row) {
            $cursor += $effectiveWeights[$index] ?? 10;

            if ($roll <= $cursor) {
                return $row;
            }
        }

        return $rows[array_key_last($rows)];
    }

    /**
     * @param array<int, object> $games
     * @return array<int, object>
     */
    private function ticketGameSequence(array $games, int $ticketCount): array
    {
        $countsByGameId = $this->ticketCountsByGameId($games, $ticketCount);
        $sequence = [];

        foreach ($games as $game) {
            $gameId = (string) $game->id;
            $count = max(0, (int) ($countsByGameId[$gameId] ?? 0));

            for ($index = 0; $index < $count; $index++) {
                $sequence[] = $game;
            }
        }

        shuffle($sequence);

        return $sequence;
    }

    /**
     * @param array<int, object> $games
     * @return array<string, int>
     */
    private function ticketCountsByGameId(array $games, int $ticketCount): array
    {
        $raw = trim((string) $this->option('tickets-per-game'));

        if ($raw !== '') {
            $parts = array_values(array_filter(array_map('trim', explode(',', $raw)), fn (string $value): bool => $value !== ''));

            if (count($parts) !== count($games)) {
                throw new \InvalidArgumentException('The --tickets-per-game option must provide '.count($games).' comma-separated counts.');
            }

            $counts = array_map(function (string $value): int {
                if (! preg_match('/^\d+$/', $value)) {
                    throw new \InvalidArgumentException('The --tickets-per-game option accepts positive integer counts only.');
                }

                return (int) $value;
            }, $parts);

            $total = array_sum($counts);
            if ($total < 1 || $total > self::SAMPLE_CUSTOMER_LIMIT) {
                throw new \InvalidArgumentException('The --tickets-per-game total must be between 1 and '.number_format(self::SAMPLE_CUSTOMER_LIMIT).'.');
            }

            $oldestFirst = $games;
            usort($oldestFirst, function (object $left, object $right): int {
                $leftDraw = (string) ($left->draw_at ?? $left->created_at ?? '');
                $rightDraw = (string) ($right->draw_at ?? $right->created_at ?? '');

                return [$leftDraw, (string) $left->id] <=> [$rightDraw, (string) $right->id];
            });

            $mapped = [];
            foreach ($oldestFirst as $index => $game) {
                $mapped[(string) $game->id] = $counts[$index];
            }

            return $mapped;
        }

        $weights = array_slice([58, 42, 28, 18, 12], 0, count($games));
        while (count($weights) < count($games)) {
            $weights[] = 10;
        }

        $totalWeight = max(1, array_sum($weights));
        $remaining = $ticketCount;
        $mapped = [];

        foreach ($games as $index => $game) {
            $count = $index === count($games) - 1
                ? $remaining
                : (int) floor(($ticketCount * $weights[$index]) / $totalWeight);
            $mapped[(string) $game->id] = max(0, $count);
            $remaining -= $mapped[(string) $game->id];
        }

        return $mapped;
    }

    /**
     * @return array{0: string, 1: string, 2: string}
     */
    private function customerName(int $index): array
    {
        $first = self::FIRST_NAMES[($index + random_int(0, count(self::FIRST_NAMES) - 1)) % count(self::FIRST_NAMES)];
        $last = self::LAST_NAMES[(($index * 3) + random_int(0, count(self::LAST_NAMES) - 1)) % count(self::LAST_NAMES)];

        return [$first, $last, $first.' '.$last];
    }

    private function emailAddress(int $index, string $firstName, string $lastName): string
    {
        $domains = ['gmail.com', 'outlook.com', 'yahoo.com', 'icloud.com'];
        $domain = $domains[$index % count($domains)];
        $slug = strtolower(substr(sha1($firstName.$lastName.$index), 0, 10));

        return 'customer.'.$slug.'@'.$domain;
    }

    private function topupAmount(int $index): int
    {
        $amounts = [10000, 20000, 50000, 100000, 200000, 500000];
        $weights = [8, 18, 26, 24, 18, 6];

        return $this->weightedPick($amounts, $weights);
    }

    /**
     * @param array<int, array<string, mixed>> $winningRows
     * @param array<string, mixed>|null $claimRow
     */
    private function ticketStatus(array $winningRows, ?array $claimRow): string
    {
        if ($winningRows === []) {
            return 'non_winning';
        }

        if (($claimRow['status'] ?? null) === 'approved') {
            return 'paid_out';
        }

        return 'winning';
    }

    private function userAgent(int $index): string
    {
        $agents = [
            'Mozilla/5.0 (iPhone; CPU iPhone OS 17_5 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.5 Mobile/15E148 Safari/604.1',
            'Mozilla/5.0 (Linux; Android 14; SM-S928B) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/125.0 Mobile Safari/537.36',
            'Mozilla/5.0 (Macintosh; Intel Mac OS X 14_5) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/125.0 Safari/537.36',
            'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/125.0 Safari/537.36',
        ];

        return $agents[$index % count($agents)];
    }

    private function ticketNumber(int $globalIndex, int $perGameIndex, string $gameId): string
    {
        $winnerSeeds = $this->winnerSeedNumbersByGame[$gameId] ?? [];

        if ($winnerSeeds !== [] && ($perGameIndex % 29 === 0 || random_int(1, 1000) <= 18)) {
            return $winnerSeeds[(int) floor($perGameIndex / 33) % count($winnerSeeds)];
        }

        $number = random_int(0, 999999);

        return str_pad((string) $number, 6, '0', STR_PAD_LEFT);
    }

    private function paidAtFor(int $index, object $game): CarbonImmutable
    {
        $start = $game->sale_start_at === null
            ? CarbonImmutable::parse((string) $game->draw_at)->subDays(7)
            : CarbonImmutable::parse((string) $game->sale_start_at);
        $close = $game->close_at === null
            ? CarbonImmutable::parse((string) $game->draw_at)->subHours(2)
            : CarbonImmutable::parse((string) $game->close_at);

        if ($close->lessThanOrEqualTo($start)) {
            $close = $start->addDays(1);
        }

        $windowMinutes = max(1, (int) $start->diffInMinutes($close));
        $offset = random_int(0, $windowMinutes - 1);

        return $start->addMinutes($offset)->addSeconds(random_int(0, 59));
    }

    private function claimStatus(int $index): string
    {
        $roll = random_int(1, 100);

        return match (true) {
            $roll <= 58 => 'approved',
            $roll <= 74 => 'submitted',
            $roll <= 88 => 'under_review',
            default => 'rejected',
        };
    }

    private function paymentProvider(int $index): string
    {
        $roll = random_int(1, 100);

        return match (true) {
            $roll <= 45 => 'wallet',
            $roll <= 74 => 'promptpay',
            $roll <= 92 => 'bank_transfer',
            default => 'credit_card',
        };
    }

    private function topupChannel(int $index): string
    {
        $roll = random_int(1, 100);

        return match (true) {
            $roll <= 42 => 'promptpay',
            $roll <= 72 => 'mobile_banking',
            $roll <= 92 => 'bank_transfer',
            default => 'manual_counter',
        };
    }

    private function visitSource(int $index): string
    {
        $roll = random_int(1, 100);

        return match (true) {
            $roll <= 28 => 'direct',
            $roll <= 50 => 'google',
            $roll <= 70 => 'line',
            $roll <= 88 => 'facebook',
            default => 'affiliate',
        };
    }

    private function visitChannel(int $index): string
    {
        $roll = random_int(1, 100);

        return match (true) {
            $roll <= 36 => 'direct',
            $roll <= 62 => 'organic',
            $roll <= 82 => 'referral',
            default => 'paid_social',
        };
    }

    private function visitPath(int $index): string
    {
        return match ($index % 6) {
            0 => '/',
            1 => '/buy',
            2 => '/tickets',
            3 => '/result',
            4 => '/profile',
            default => '/waiting-result',
        };
    }

    /**
     * @return array<string, string>
     */
    private function bankAccount(int $index, string $name): array
    {
        $bank = self::BANKS[$index % count(self::BANKS)];

        return [
            'bank_name' => $bank['name'],
            'account_name' => $name,
            'account_number' => $bank['prefix'].str_pad((string) random_int(10000000, 99999999), 8, '0', STR_PAD_LEFT).'1244',
            'branch' => $bank['branch'],
        ];
    }

    private function phoneNumber(int $index): string
    {
        return '09'.str_pad((string) ($index % 100000000), 8, '0', STR_PAD_LEFT);
    }

    private function mockId(string $prefix, int $index, ?int $subIndex = null): string
    {
        $id = $prefix.'_rt_'.str_pad((string) $index, 5, '0', STR_PAD_LEFT);

        if ($subIndex !== null) {
            $id .= '_'.str_pad((string) $subIndex, 2, '0', STR_PAD_LEFT);
        }

        return substr($id, 0, 30);
    }

    private function queue(string $table, array $row): void
    {
        if (! Schema::hasTable($table)) {
            return;
        }

        $row = $this->filterColumns($table, $row);

        if ($row === []) {
            return;
        }

        $this->pending[$table][] = $row;
    }

    private function pendingCount(string $table): int
    {
        return count($this->pending[$table] ?? []);
    }

    private function flushPending(): void
    {
        $order = [
            'customers' => ['id'],
            'wallets' => ['id'],
            'stock_items' => ['id'],
            'local_stock_items' => ['id'],
            'stock_reservations' => ['id'],
            'stock_reservation_items' => ['reservation_id', 'local_stock_item_id'],
            'orders' => ['id'],
            'tickets' => ['id'],
            'order_items' => ['id'],
            'topup_requests' => ['id'],
            'payments' => ['id'],
            'affiliate_programs' => ['id'],
            'commission_rules' => ['id'],
            'affiliate_accounts' => ['id'],
            'affiliate_links' => ['id'],
            'affiliate_attributions' => ['id'],
            'commission_transactions' => ['id'],
            'affiliate_payouts' => ['id'],
            'public_visit_sessions' => ['id'],
            'customer_auth_sessions' => ['id'],
            'admin_auth_sessions' => ['id'],
            'winning_tickets' => ['id'],
            'wallet_ledger' => ['id'],
            'reward_claims' => ['id'],
        ];

        foreach ($order as $table => $uniqueBy) {
            $rows = $this->pending[$table] ?? [];

            if ($rows === []) {
                continue;
            }

            $this->upsertRows($table, $rows, $uniqueBy);
            $this->pending[$table] = [];
        }
    }

    /**
     * @param array<int, array<string, mixed>> $rows
     * @param array<int, string> $uniqueBy
     */
    private function upsertRows(string $table, array $rows, array $uniqueBy): void
    {
        if ($rows === [] || ! Schema::hasTable($table)) {
            return;
        }

        $filtered = array_values(array_filter(array_map(fn (array $row): array => $this->filterColumns($table, $row), $rows)));

        if ($filtered === []) {
            return;
        }

        foreach (array_chunk($filtered, $this->chunkSize) as $chunk) {
            $columns = array_keys($chunk[0]);
            $updateColumns = array_values(array_diff($columns, $uniqueBy));

            DB::table($table)->upsert($chunk, $uniqueBy, $updateColumns);
        }
    }

    /**
     * @return array<string, mixed>
     */
    private function filterColumns(string $table, array $row): array
    {
        $columns = $this->columns[$table] ??= Schema::getColumnListing($table);
        $allowed = array_flip($columns);

        return array_intersect_key($row, $allowed);
    }

    private function resetMockRows(): void
    {
        $this->line('Resetting previous runtime sample rows...');

        foreach (['mock', 'rt'] as $tag) {
            $this->setNullWherePrefix('payments', 'pay_'.$tag.'_', ['topup_request_id']);
            $this->setNullWherePrefix('topup_requests', 'top_'.$tag.'_', ['payment_id']);

            $this->deleteWherePrefix('admin_auth_sessions', 'id', 'aas_'.$tag.'_');
            $this->deleteWherePrefix('customer_auth_sessions', 'id', 'cas_'.$tag.'_');
            $this->deleteWherePrefix('public_visit_sessions', 'id', 'pvs_'.$tag.'_');
            $this->deleteWherePrefix('affiliate_payouts', 'id', 'afpayout_'.$tag.'_');
            $this->deleteWherePrefix('commission_transactions', 'id', 'com_'.$tag.'_');
            $this->deleteWherePrefix('affiliate_attributions', 'id', 'atr_'.$tag.'_');
            $this->deleteWherePrefix('affiliate_links', 'id', 'afl_'.$tag.'_');
            $this->deleteWherePrefix('affiliate_accounts', 'id', 'aff_'.$tag.'_');
            $this->deleteWherePrefix('commission_rules', 'id', 'cmr_'.$tag.'_');
            $this->deleteWherePrefix('affiliate_programs', 'id', 'afp_'.$tag.'_');
            $this->deleteWherePrefix('reward_claims', 'id', 'rcl_'.$tag.'_');
            $this->deleteWherePrefix('winning_tickets', 'id', 'win_'.$tag.'_');
            $this->deleteWherePrefix('reward_check_items', 'id', 'rci_'.$tag.'_');
            $this->deleteWherePrefix('reward_check_batches', 'id', 'rcb_'.$tag.'_');
            $this->deleteWherePrefix('wallet_ledger', 'id', 'wlt_'.$tag.'_');
            $this->deleteWherePrefix('wallet_ledger', 'id', 'wld_'.$tag.'_');
            $this->deleteWherePrefix('wallet_ledger', 'id', 'wlp_'.$tag.'_');
            $this->deleteWherePrefix('payments', 'id', 'pay_'.$tag.'_');
            $this->deleteWherePrefix('topup_requests', 'id', 'top_'.$tag.'_');
            $this->deleteWherePrefix('order_items', 'id', 'oit_'.$tag.'_');
            $this->deleteWherePrefix('tickets', 'id', 'tck_'.$tag.'_');
            $this->deleteWherePrefix('orders', 'id', 'ord_'.$tag.'_');
            $this->deleteWherePrefix('stock_reservation_items', 'reservation_id', 'res_'.$tag.'_');
            $this->deleteWherePrefix('stock_reservations', 'id', 'res_'.$tag.'_');
            $this->deleteWherePrefix('local_stock_items', 'id', 'lsi_'.$tag.'_');
            $this->deleteWherePrefix('stock_items', 'id', 'stk_'.$tag.'_');
            $this->deleteWherePrefix('wallets', 'id', 'wal_'.$tag.'_');
            $this->deleteWherePrefix('customers', 'id', 'cus_'.$tag.'_');
        }
    }

    /**
     * @param array<int, string> $columns
     */
    private function setNullWherePrefix(string $table, string $idPrefix, array $columns): void
    {
        if (! Schema::hasTable($table) || ! Schema::hasColumn($table, 'id')) {
            return;
        }

        $payload = [];

        foreach ($columns as $column) {
            if (Schema::hasColumn($table, $column)) {
                $payload[$column] = null;
            }
        }

        if ($payload === []) {
            return;
        }

        DB::table($table)->where('id', 'like', $idPrefix.'%')->update($payload);
    }

    private function deleteWherePrefix(string $table, string $column, string $prefix): void
    {
        if (! Schema::hasTable($table) || ! Schema::hasColumn($table, $column)) {
            return;
        }

        DB::table($table)->where($column, 'like', $prefix.'%')->delete();
    }

    private function json(array $payload): string
    {
        try {
            return json_encode($payload, JSON_THROW_ON_ERROR | JSON_UNESCAPED_UNICODE | JSON_UNESCAPED_SLASHES);
        } catch (Throwable) {
            return '{}';
        }
    }

    private function date(CarbonImmutable $date): string
    {
        return $date->setTimezone(config('app.timezone', 'Asia/Bangkok'))->format('Y-m-d H:i:sP');
    }
}
