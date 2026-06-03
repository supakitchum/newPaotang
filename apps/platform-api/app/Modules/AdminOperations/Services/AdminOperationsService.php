<?php

namespace App\Modules\AdminOperations\Services;

use App\Models\AdminMenu;
use App\Models\AdminUser;
use App\Models\AdminUserRole;
use App\Models\AuditLog;
use App\Models\Partner;
use App\Models\PartnerTenant;
use App\Models\Role;
use App\Shared\Audit\AuditLogger;
use App\Shared\Auth\AdminSessionContext;
use Carbon\CarbonImmutable;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Schema;

class AdminOperationsService
{
    public function __construct(private readonly AuditLogger $auditLogger)
    {
    }

    /**
     * @return array<string, mixed>
     */
    public function dashboardSummary(string $scopeType, ?string $tenantId, string $period = 'today'): array
    {
        if ($scopeType === 'tenant') {
            return $this->tenantDashboardSummary($tenantId, $period);
        }

        $isCentral = $scopeType === 'central';
        $summary = [
            'scope' => $scopeType,
            'tenant_id' => null,
            'generated_at' => now()->toISOString(),
            'kpis' => $this->centralDashboardKpis(),
            'charts' => $isCentral ? $this->centralDashboardCharts() : [
                'activity' => [
                    'labels' => [],
                    'series' => [],
                ],
            ],
            'tables' => $isCentral ? $this->centralDashboardTables() : [],
            'finance' => $isCentral ? $this->centralDashboardFinance() : [],
            'alerts' => $isCentral ? $this->centralDashboardAlerts() : [],
        ];

        return $summary;
    }

    /**
     * @return array<string, mixed>
     */
    public function centralDashboardSection(string $section, string $period): array
    {
        $section = in_array($section, ['sales', 'partner', 'wallet', 'payout', 'monitor'], true) ? $section : 'sales';
        $window = $this->centralDashboardPeriod($period, $section);

        return [
            'scope' => 'central',
            'section' => $section,
            'title' => $this->centralDashboardSectionTitle($section),
            'generated_at' => now()->toISOString(),
            'filter' => [
                'period' => $window['key'],
                'label' => $window['label'],
                'current' => [
                    'label' => $window['current_label'],
                    'start_at' => $this->isoDate($window['current_start']),
                    'end_at' => $this->isoDate($window['current_end']),
                    'game_id' => $window['game_id'],
                ],
                'previous' => [
                    'label' => $window['previous_label'],
                    'start_at' => $this->isoDate($window['previous_start']),
                    'end_at' => $this->isoDate($window['previous_end']),
                    'game_id' => $window['previous_game_id'],
                ],
                'options' => $this->centralDashboardPeriodOptions($section),
            ],
            'sections' => $this->centralDashboardNavigation(),
            ...match ($section) {
                'partner' => $this->centralPartnerDashboard($window),
                'wallet' => $this->centralWalletDashboard($window),
                'payout' => $this->centralPayoutDashboard($window),
                'monitor' => $this->centralMonitorDashboard($window),
                default => $this->centralSalesDashboard($window),
            },
        ];
    }

    /**
     * @param array<string, mixed> $payload
     * @return array<string, array<int, string>>
     */
    public function realtimeValidationErrors(array $payload): array
    {
        $errors = [];

        foreach (['socket_id', 'channel_name'] as $field) {
            if (! array_key_exists($field, $payload) || ! is_string($payload[$field]) || trim($payload[$field]) === '') {
                $errors[$field][] = 'The '.$field.' field is required.';
            }
        }

        if (array_key_exists('socket_id', $payload) && is_string($payload['socket_id']) && strlen($payload['socket_id']) > 120) {
            $errors['socket_id'][] = 'The socket_id field must not exceed 120 characters.';
        }

        if (array_key_exists('channel_name', $payload) && is_string($payload['channel_name']) && strlen($payload['channel_name']) > 200) {
            $errors['channel_name'][] = 'The channel_name field must not exceed 200 characters.';
        }

        return $errors;
    }

    /**
     * @param array<string, mixed> $payload
     * @return array<string, mixed>|null
     */
    public function realtimeAuth(AdminSessionContext $context, string $scopeType, array $payload): ?array
    {
        $socketId = trim((string) $payload['socket_id']);
        $channelName = trim((string) $payload['channel_name']);

        if (! $this->isAllowedAdminChannel($context, $scopeType, $channelName)) {
            return null;
        }

        $channelData = null;
        $stringToSign = $socketId.':'.$channelName;

        if (str_starts_with($channelName, 'presence-')) {
            $channelData = json_encode([
                'user_id' => $context->adminUser['id'],
                'user_info' => [
                    'name' => $context->adminUser['name'],
                    'scope' => $scopeType,
                    'tenant_id' => $context->activeTenantId(),
                ],
            ], JSON_THROW_ON_ERROR);

            $stringToSign .= ':'.$channelData;
        }

        $key = (string) config('platform.realtime.admin_key', 'newpaotang-admin');
        $secret = (string) config('platform.realtime.admin_secret', 'newpaotang-admin-secret');

        if ($key === '') {
            $key = 'newpaotang-admin';
        }

        if ($secret === '') {
            $secret = 'newpaotang-admin-secret';
        }

        return [
            'auth' => $key.':'.hash_hmac('sha256', $stringToSign, $secret),
            'channel_data' => $channelData,
            'expires_at' => now()->addSeconds((int) config('platform.realtime.auth_ttl_seconds', 300))->toISOString(),
        ];
    }

    public function requiredRealtimePermission(string $scopeType, string $channelName): ?string
    {
        if ($scopeType === 'tenant') {
            if ($this->isTenantStockChannel($channelName) || $this->isTenantStockCoverageChannel($channelName)) {
                return 'stock.view';
            }

            if ($this->isTenantTopupsChannel($channelName)) {
                return 'topup.view';
            }

            return null;
        }

        if ($this->isCentralStockGenerationChannel($channelName)) {
            return 'stock.generate';
        }

        if ($this->isCentralStockTableChannel($channelName)) {
            return 'stock.view';
        }

        return null;
    }

    /**
     * @param array<string, mixed> $queryParams
     * @return array{data: array<int, array<string, mixed>>, meta: array<string, mixed>}
     */
    public function auditLogs(string $scopeType, ?string $tenantId, array $queryParams): array
    {
        $limit = $this->limit($queryParams['limit'] ?? null);
        $query = AuditLog::query()
            ->where('scope_type', $scopeType)
            ->orderByDesc('created_at')
            ->orderByDesc('id');

        if ($scopeType === 'tenant') {
            $query->where('tenant_id', $tenantId);
        } else {
            $query->whereNull('tenant_id');
        }

        if (($queryParams['action'] ?? null) !== null && trim((string) $queryParams['action']) !== '') {
            $query->where('action', trim((string) $queryParams['action']));
        }

        if (($queryParams['actor_id'] ?? null) !== null && trim((string) $queryParams['actor_id']) !== '') {
            $query->where('actor_id', trim((string) $queryParams['actor_id']));
        }

        $cursor = $this->decodeCursor($queryParams['cursor'] ?? null);

        if ($cursor !== null) {
            $query->where(function ($nested) use ($cursor): void {
                $nested->where('created_at', '<', $cursor['created_at'])
                    ->orWhere(function ($sameCreatedAt) use ($cursor): void {
                        $sameCreatedAt->where('created_at', '=', $cursor['created_at'])
                            ->where('id', '<', $cursor['id']);
                    });
            });
        }

        $rows = $query->limit($limit + 1)->get()->all();
        $hasMore = count($rows) > $limit;
        $rows = array_slice($rows, 0, $limit);

        return [
            'data' => array_map(fn (object $row): array => $this->auditLogResource($row), $rows),
            'meta' => [
                'next_cursor' => $hasMore && $rows !== [] ? $this->encodeCursor($rows[array_key_last($rows)]) : null,
                'has_more' => $hasMore,
            ],
        ];
    }

    /**
     * @return array<string, int>
     */
    private function centralDashboardKpis(): array
    {
        $paidOrders = $this->paidOrdersQuery();

        return [
            'partners_total' => Partner::count(),
            'partners_active' => Partner::where('status', 'active')->count(),
            'tenants_total' => PartnerTenant::count(),
            'tenants_active' => PartnerTenant::where('status', 'active')->count(),
            'admin_users_total' => AdminUser::count(),
            'roles_total' => Role::where('scope_type', 'central')->whereNull('tenant_id')->count(),
            'menus_total' => AdminMenu::where('scope_type', 'central')->count(),
            'audit_logs_total' => AuditLog::where('scope_type', 'central')->whereNull('tenant_id')->count(),
            'games_open' => $this->countTable('games', fn ($query) => $query->where('status', 'open')),
            'orders_paid' => $paidOrders === null ? 0 : (int) $paidOrders->count(),
            'sales_amount' => $this->paidOrdersSum('total_amount'),
            'tickets_sold' => $this->paidTicketsCount(),
            'stock_available' => $this->countTable('stock_items', fn ($query) => $query->where('status', 'available')),
            'stock_allocated' => $this->countTable('stock_items', fn ($query) => $query->whereIn('status', ['allocated', 'reserved'])),
            'pending_reward_claims' => $this->countTable('reward_claims', fn ($query) => $query->whereIn('status', ['submitted', 'under_review'])),
            'open_alerts' => $this->countTable('partner_alert_events', fn ($query) => $query->where('status', 'open')),
            'wallet_balance_amount' => $this->sumTable('wallets', 'balance_amount', fn ($query) => $query->where('status', 'active')),
            'pending_topups' => $this->countTable('topup_requests', fn ($query) => $query->whereIn('status', ['pending', 'submitted', 'under_review'])),
        ];
    }

    /**
     * @return array<string, mixed>
     */
    private function centralDashboardCharts(): array
    {
        $currentGame = $this->centralDashboardCurrentGame();
        $currentGameId = $currentGame['id'] ?? null;

        return [
            'activity' => $this->centralSalesTrend(),
            'sales_trend' => $this->centralSalesTrend(),
            'sales_by_game' => $this->centralSalesByGameTrend(),
            'usage_trend' => $this->centralUsageTrend(),
            'orders_by_status' => $this->statusBreakdown('orders'),
            'stock_by_status' => $this->statusBreakdown('stock_items', filter: $currentGameId === null
                ? null
                : fn ($query) => $query->where('game_id', $currentGameId)),
            'reward_claims_by_status' => $this->statusBreakdown('reward_claims'),
            'partner_health_by_status' => $this->statusBreakdown('partner_health_checks', 'health_status'),
            'partner_status' => $this->statusBreakdown('partners'),
            'tenant_status' => $this->statusBreakdown('partner_tenants'),
            'alert_severity' => $this->statusBreakdown('partner_alert_events', 'severity', fn ($query) => $query->where('status', 'open')),
        ];
    }

    /**
     * @return array<string, mixed>
     */
    private function centralDashboardTables(): array
    {
        return [
            'current_game' => $this->centralDashboardCurrentGame(),
            'recent_games' => $this->centralDashboardRecentGames(),
            'top_partners' => $this->centralDashboardTopPartners(),
            'top_tenants' => $this->centralDashboardTopTenants(),
            'open_alerts' => $this->centralDashboardOpenAlerts(),
            'recent_settlements' => $this->centralDashboardRecentSettlements(),
            'recent_activity' => $this->centralDashboardRecentActivity(),
        ];
    }

    /**
     * @return array<int, array<string, mixed>>
     */
    private function centralDashboardAlerts(): array
    {
        return array_map(
            fn (array $row): array => [
                'id' => $row['id'],
                'message' => $row['title'],
                'severity' => $row['severity'],
                'status' => $row['status'],
                'triggered_at' => $row['triggered_at'],
            ],
            $this->centralDashboardOpenAlerts(),
        );
    }

    /**
     * @return array<string, mixed>
     */
    private function centralDashboardFinance(): array
    {
        $currentGame = $this->centralDashboardCurrentGameRow();
        $previousGame = $this->centralDashboardPreviousGameRow($currentGame);
        $current = $currentGame === null ? null : $this->centralDashboardFinanceGameSnapshot($currentGame);
        $previous = $previousGame === null ? null : $this->centralDashboardFinanceGameSnapshot($previousGame);

        return [
            'current_game' => $current,
            'previous_game' => $previous,
            'metrics' => [
                $this->financeMetric('sales_amount', 'Paid sales', 'money', $current['sales_amount_value'] ?? null, $previous['sales_amount_value'] ?? null),
                $this->financeMetric('tickets_sold', 'Tickets sold', 'number', $current['tickets_sold'] ?? null, $previous['tickets_sold'] ?? null),
                $this->financeMetric('paid_orders', 'Paid orders', 'number', $current['paid_orders'] ?? null, $previous['paid_orders'] ?? null),
                $this->financeMetric('average_order_amount', 'Average order', 'money', $current['average_order_amount_value'] ?? null, $previous['average_order_amount_value'] ?? null),
                $this->financeMetric('paid_customers', 'Paid customers', 'number', $current['paid_customers'] ?? null, $previous['paid_customers'] ?? null),
            ],
            'comparison_chart' => [
                $this->financeComparisonRow('sales_amount', 'Sales', 'money', $current['sales_amount_value'] ?? null, $previous['sales_amount_value'] ?? null),
                $this->financeComparisonRow('tickets_sold', 'Tickets', 'number', $current['tickets_sold'] ?? null, $previous['tickets_sold'] ?? null),
                $this->financeComparisonRow('paid_orders', 'Orders', 'number', $current['paid_orders'] ?? null, $previous['paid_orders'] ?? null),
                $this->financeComparisonRow('paid_customers', 'Customers', 'number', $current['paid_customers'] ?? null, $previous['paid_customers'] ?? null),
            ],
        ];
    }

    /**
     * @return array<string, mixed>
     */
    private function centralDashboardFinanceGameSnapshot(object $game): array
    {
        $gameId = (string) $game->id;
        $salesAmount = $this->paidOrdersSum('total_amount', $gameId);
        $paidOrders = $this->paidOrdersCount($gameId);
        $ticketsSold = $this->paidTicketsCount($gameId);
        $paidCustomers = $this->paidCustomersCount($gameId);
        $averageOrderAmount = $paidOrders > 0 ? (int) round($salesAmount / $paidOrders) : 0;
        $averageTicketAmount = $ticketsSold > 0 ? (int) round($salesAmount / $ticketsSold) : 0;

        return [
            'id' => $gameId,
            'code' => (string) $game->code,
            'name' => (string) $game->name,
            'status' => (string) $game->status,
            'sale_start_at' => $this->isoDate($game->sale_start_at ?? null),
            'close_at' => $this->isoDate($game->close_at ?? null),
            'draw_at' => $this->isoDate($game->draw_at ?? null),
            'sales_amount' => $this->money($salesAmount),
            'sales_amount_value' => $salesAmount,
            'paid_orders' => $paidOrders,
            'tickets_sold' => $ticketsSold,
            'paid_customers' => $paidCustomers,
            'average_order_amount' => $this->money($averageOrderAmount),
            'average_order_amount_value' => $averageOrderAmount,
            'average_ticket_amount' => $this->money($averageTicketAmount),
            'average_ticket_amount_value' => $averageTicketAmount,
        ];
    }

    /**
     * @return array<string, mixed>
     */
    private function financeMetric(string $key, string $label, string $type, ?int $current, ?int $previous): array
    {
        $currentValue = $current ?? 0;
        $hasPrevious = $previous !== null;
        $previousValue = $previous ?? 0;
        $delta = $hasPrevious ? $currentValue - $previousValue : null;

        return [
            'key' => $key,
            'label' => $label,
            'type' => $type,
            'current' => $currentValue,
            'previous' => $hasPrevious ? $previousValue : null,
            'delta' => $delta,
            'percent' => $delta === null || $previousValue === 0 ? null : round(($delta / $previousValue) * 100, 2),
            'direction' => $delta === null || $delta === 0 ? 'flat' : ($delta > 0 ? 'up' : 'down'),
            'baseline_available' => $hasPrevious,
        ];
    }

    /**
     * @return array<string, mixed>
     */
    private function financeComparisonRow(string $key, string $label, string $type, ?int $current, ?int $previous): array
    {
        return [
            'key' => $key,
            'label' => $label,
            'type' => $type,
            'current' => $current ?? 0,
            'previous' => $previous ?? 0,
        ];
    }

    /**
     * @return array<string, mixed>
     */
    private function centralSalesTrend(): array
    {
        $days = $this->recentDayKeys(14);
        $orderCounts = array_fill_keys($days, 0);
        $paidOrderCounts = array_fill_keys($days, 0);
        $ticketCounts = array_fill_keys($days, 0);
        $salesAmounts = array_fill_keys($days, 0);

        if ($this->tableExists('orders')) {
            $rows = DB::table('orders')
                ->where('created_at', '>=', CarbonImmutable::parse($days[0])->startOfDay())
                ->select(['created_at', 'status', 'payment_status', 'paid_at', 'total_amount'])
                ->get();

            foreach ($rows as $row) {
                $day = $this->dayKey($row->created_at);
                if (! array_key_exists($day, $orderCounts)) {
                    continue;
                }

                $orderCounts[$day]++;
                if ($this->isPaidOrderRow($row)) {
                    $paidOrderCounts[$day]++;
                    $salesAmounts[$day] += (int) $row->total_amount;
                }
            }
        }

        if ($this->tableExists('tickets')) {
            $rows = DB::table('tickets')
                ->where('created_at', '>=', CarbonImmutable::parse($days[0])->startOfDay())
                ->select(['created_at'])
                ->get();

            foreach ($rows as $row) {
                $day = $this->dayKey($row->created_at);
                if (array_key_exists($day, $ticketCounts)) {
                    $ticketCounts[$day]++;
                }
            }
        }

        return [
            'labels' => array_map(fn (string $day): string => CarbonImmutable::parse($day)->format('d M'), $days),
            'keys' => $days,
            'series' => [
                ['key' => 'orders', 'label' => 'Orders', 'values' => array_values($orderCounts)],
                ['key' => 'paid_orders', 'label' => 'Paid orders', 'values' => array_values($paidOrderCounts)],
                ['key' => 'tickets', 'label' => 'Tickets sold', 'values' => array_values($ticketCounts)],
                ['key' => 'sales_amount', 'label' => 'Sales amount', 'type' => 'money', 'values' => array_values($salesAmounts)],
            ],
        ];
    }

    /**
     * @return array<string, mixed>
     */
    private function centralSalesByGameTrend(): array
    {
        if (! $this->tableExists('games')) {
            return [
                'labels' => [],
                'keys' => [],
                'series' => [],
            ];
        }

        $games = DB::table('games')
            ->orderByDesc('draw_at')
            ->limit(8)
            ->get()
            ->reverse()
            ->values();
        $labels = [];
        $keys = [];
        $salesAmounts = [];
        $ticketsSold = [];
        $paidOrders = [];
        $averageOrders = [];

        foreach ($games as $game) {
            $snapshot = $this->centralDashboardFinanceGameSnapshot($game);
            $labels[] = $game->draw_at === null
                ? (string) $game->code
                : CarbonImmutable::parse($game->draw_at)->format('d M');
            $keys[] = (string) $game->id;
            $salesAmounts[] = $snapshot['sales_amount_value'];
            $ticketsSold[] = $snapshot['tickets_sold'];
            $paidOrders[] = $snapshot['paid_orders'];
            $averageOrders[] = $snapshot['average_order_amount_value'];
        }

        return [
            'labels' => $labels,
            'keys' => $keys,
            'series' => [
                ['key' => 'sales_amount', 'label' => 'Sales amount', 'type' => 'money', 'values' => $salesAmounts],
                ['key' => 'tickets', 'label' => 'Tickets sold', 'values' => $ticketsSold],
                ['key' => 'paid_orders', 'label' => 'Paid orders', 'values' => $paidOrders],
                ['key' => 'average_order_amount', 'label' => 'Average order', 'type' => 'money', 'values' => $averageOrders],
            ],
        ];
    }

    /**
     * @return array<string, mixed>
     */
    private function centralUsageTrend(): array
    {
        $days = $this->recentDayKeys(14);
        $apiRequests = array_fill_keys($days, 0);
        $errors = array_fill_keys($days, 0);
        $orders = array_fill_keys($days, 0);
        $soldTickets = array_fill_keys($days, 0);

        if ($this->tableExists('partner_daily_usage_summaries')) {
            $rows = DB::table('partner_daily_usage_summaries')
                ->where('usage_date', '>=', $days[0])
                ->select([
                    'usage_date',
                    DB::raw('SUM(api_request_count) as api_request_count'),
                    DB::raw('SUM(error_count) as error_count'),
                    DB::raw('SUM(order_count) as order_count'),
                    DB::raw('SUM(sold_ticket_count) as sold_ticket_count'),
                ])
                ->groupBy('usage_date')
                ->get();

            foreach ($rows as $row) {
                $day = (string) $row->usage_date;
                if (! array_key_exists($day, $apiRequests)) {
                    continue;
                }

                $apiRequests[$day] = (int) $row->api_request_count;
                $errors[$day] = (int) $row->error_count;
                $orders[$day] = (int) $row->order_count;
                $soldTickets[$day] = (int) $row->sold_ticket_count;
            }
        }

        return [
            'labels' => array_map(fn (string $day): string => CarbonImmutable::parse($day)->format('d M'), $days),
            'keys' => $days,
            'series' => [
                ['key' => 'api_requests', 'label' => 'API requests', 'values' => array_values($apiRequests)],
                ['key' => 'errors', 'label' => 'Errors', 'values' => array_values($errors)],
                ['key' => 'orders', 'label' => 'Orders', 'values' => array_values($orders)],
                ['key' => 'sold_tickets', 'label' => 'Tickets sold', 'values' => array_values($soldTickets)],
            ],
        ];
    }

    /**
     * @return array<string, mixed>|null
     */
    private function centralDashboardCurrentGame(): ?array
    {
        $game = $this->centralDashboardCurrentGameRow();

        return $game === null ? null : $this->centralDashboardGameResource($game);
    }

    private function centralDashboardCurrentGameRow(): ?object
    {
        if (! $this->tableExists('games')) {
            return null;
        }

        $game = DB::table('games')
            ->where('status', 'open')
            ->orderByDesc('sale_start_at')
            ->orderByDesc('draw_at')
            ->first();

        if ($game !== null) {
            return $game;
        }

        $game = DB::table('games')
            ->where('draw_at', '>=', now())
            ->orderBy('draw_at')
            ->first();

        return $game ?? DB::table('games')
            ->orderByDesc('draw_at')
            ->first();
    }

    private function centralDashboardPreviousGameRow(?object $currentGame): ?object
    {
        if ($currentGame === null || ! $this->tableExists('games')) {
            return null;
        }

        $gameId = (string) $currentGame->id;
        $drawAt = $currentGame->draw_at ?? null;

        if ($drawAt !== null) {
            $previous = DB::table('games')
                ->where('id', '<>', $gameId)
                ->where('draw_at', '<', $drawAt)
                ->orderByDesc('draw_at')
                ->first();

            if ($previous !== null) {
                return $previous;
            }
        }

        return DB::table('games')
            ->where('id', '<>', $gameId)
            ->orderByDesc('draw_at')
            ->first();
    }

    /**
     * @return array<int, array<string, mixed>>
     */
    private function centralDashboardRecentGames(): array
    {
        if (! $this->tableExists('games')) {
            return [];
        }

        return DB::table('games')
            ->orderByDesc('draw_at')
            ->limit(6)
            ->get()
            ->map(fn (object $game): array => $this->centralDashboardGameResource($game, includeBreakdown: false))
            ->all();
    }

    /**
     * @return array<string, mixed>
     */
    private function centralDashboardGameResource(object $game, bool $includeBreakdown = true): array
    {
        $gameId = (string) $game->id;

        $resource = [
            'id' => $gameId,
            'code' => (string) $game->code,
            'name' => (string) $game->name,
            'status' => (string) $game->status,
            'sale_start_at' => $this->isoDate($game->sale_start_at ?? null),
            'close_at' => $this->isoDate($game->close_at ?? null),
            'draw_at' => $this->isoDate($game->draw_at ?? null),
            'orders_paid' => $this->paidOrdersCount($gameId),
            'sales_amount' => $this->money($this->paidOrdersSum('total_amount', $gameId)),
            'tickets_sold' => $this->paidTicketsCount($gameId),
            'stock_total' => $this->countTable('stock_items', fn ($query) => $query->where('game_id', $gameId)),
            'stock_available' => $this->countTable('stock_items', fn ($query) => $query->where('game_id', $gameId)->where('status', 'available')),
            'stock_allocated' => $this->countTable('stock_items', fn ($query) => $query->where('game_id', $gameId)->whereIn('status', ['allocated', 'reserved'])),
            'reward_status' => $this->rewardResultStatus($gameId),
        ];

        if ($includeBreakdown) {
            $resource['stock_breakdown'] = $this->statusBreakdown('stock_items', filter: fn ($query) => $query->where('game_id', $gameId));
            $resource['reward_check_breakdown'] = $this->statusBreakdown('reward_check_batches', filter: fn ($query) => $query->where('game_id', $gameId));
        }

        return $resource;
    }

    private function rewardResultStatus(string $gameId): ?string
    {
        if (! $this->tableExists('reward_results')) {
            return null;
        }

        $status = DB::table('reward_results')->where('game_id', $gameId)->value('status');

        return $status === null ? null : (string) $status;
    }

    /**
     * @return array<int, array<string, mixed>>
     */
    private function centralDashboardTopTenants(): array
    {
        if (! $this->tableExists('orders') || ! $this->tableExists('partner_tenants')) {
            return [];
        }

        return $this->paidOrdersQuery()
            ->join('partner_tenants', 'partner_tenants.id', '=', 'orders.tenant_id')
            ->leftJoin('partners', 'partners.id', '=', 'partner_tenants.partner_id')
            ->select([
                'partner_tenants.id',
                'partner_tenants.code',
                'partner_tenants.name',
                'partner_tenants.status',
                'partners.name as partner_name',
                DB::raw('COUNT(orders.id) as order_count'),
                DB::raw('COUNT(DISTINCT orders.customer_id) as customer_count'),
                DB::raw('SUM(orders.total_amount) as sales_amount'),
            ])
            ->groupBy('partner_tenants.id', 'partner_tenants.code', 'partner_tenants.name', 'partner_tenants.status', 'partners.name')
            ->orderByDesc('sales_amount')
            ->limit(6)
            ->get()
            ->map(fn (object $row): array => [
                'id' => (string) $row->id,
                'code' => (string) $row->code,
                'name' => (string) $row->name,
                'status' => (string) $row->status,
                'partner_name' => $row->partner_name === null ? null : (string) $row->partner_name,
                'order_count' => (int) $row->order_count,
                'customer_count' => (int) $row->customer_count,
                'sales_amount' => $this->money((int) $row->sales_amount),
            ])
            ->all();
    }

    /**
     * @return array<int, array<string, mixed>>
     */
    private function centralDashboardTopPartners(): array
    {
        if (! $this->tableExists('orders') || ! $this->tableExists('partner_tenants') || ! $this->tableExists('partners')) {
            return [];
        }

        return $this->paidOrdersQuery()
            ->join('partner_tenants', 'partner_tenants.id', '=', 'orders.tenant_id')
            ->join('partners', 'partners.id', '=', 'partner_tenants.partner_id')
            ->select([
                'partners.id',
                'partners.code',
                'partners.name',
                'partners.status',
                DB::raw('COUNT(DISTINCT partner_tenants.id) as tenant_count'),
                DB::raw('COUNT(orders.id) as order_count'),
                DB::raw('COUNT(DISTINCT orders.customer_id) as customer_count'),
                DB::raw('SUM(orders.total_amount) as sales_amount'),
            ])
            ->groupBy('partners.id', 'partners.code', 'partners.name', 'partners.status')
            ->orderByDesc('sales_amount')
            ->limit(6)
            ->get()
            ->map(fn (object $row): array => [
                'id' => (string) $row->id,
                'code' => (string) $row->code,
                'name' => (string) $row->name,
                'status' => (string) $row->status,
                'tenant_count' => (int) $row->tenant_count,
                'order_count' => (int) $row->order_count,
                'customer_count' => (int) $row->customer_count,
                'sales_amount' => $this->money((int) $row->sales_amount),
            ])
            ->all();
    }

    /**
     * @return array<int, array<string, mixed>>
     */
    private function centralDashboardOpenAlerts(): array
    {
        if (! $this->tableExists('partner_alert_events')) {
            return [];
        }

        return DB::table('partner_alert_events')
            ->leftJoin('partners', 'partners.id', '=', 'partner_alert_events.partner_id')
            ->leftJoin('partner_tenants', 'partner_tenants.id', '=', 'partner_alert_events.tenant_id')
            ->where('partner_alert_events.status', 'open')
            ->select([
                'partner_alert_events.id',
                'partner_alert_events.policy_key',
                'partner_alert_events.severity',
                'partner_alert_events.status',
                'partner_alert_events.title',
                'partner_alert_events.message',
                'partner_alert_events.triggered_at',
                'partners.name as partner_name',
                'partner_tenants.name as tenant_name',
            ])
            ->orderByRaw("CASE partner_alert_events.severity WHEN 'critical' THEN 0 WHEN 'warning' THEN 1 ELSE 2 END")
            ->orderByDesc('partner_alert_events.triggered_at')
            ->limit(8)
            ->get()
            ->map(fn (object $row): array => [
                'id' => (string) $row->id,
                'policy_key' => (string) $row->policy_key,
                'severity' => (string) $row->severity,
                'status' => (string) $row->status,
                'title' => (string) $row->title,
                'message' => $row->message === null ? null : (string) $row->message,
                'partner_name' => $row->partner_name === null ? null : (string) $row->partner_name,
                'tenant_name' => $row->tenant_name === null ? null : (string) $row->tenant_name,
                'triggered_at' => $this->isoDate($row->triggered_at),
            ])
            ->all();
    }

    /**
     * @return array<int, array<string, mixed>>
     */
    private function centralDashboardRecentSettlements(): array
    {
        if (! $this->tableExists('partner_settlements')) {
            return [];
        }

        return DB::table('partner_settlements')
            ->leftJoin('partners', 'partners.id', '=', 'partner_settlements.partner_id')
            ->leftJoin('partner_tenants', 'partner_tenants.id', '=', 'partner_settlements.tenant_id')
            ->select([
                'partner_settlements.id',
                'partner_settlements.status',
                'partner_settlements.net_amount',
                'partner_settlements.currency',
                'partner_settlements.period_from',
                'partner_settlements.period_to',
                'partner_settlements.updated_at',
                'partners.name as partner_name',
                'partner_tenants.name as tenant_name',
            ])
            ->orderByDesc('partner_settlements.updated_at')
            ->limit(6)
            ->get()
            ->map(fn (object $row): array => [
                'id' => (string) $row->id,
                'status' => (string) $row->status,
                'net_amount' => $this->money((int) $row->net_amount, (string) $row->currency),
                'partner_name' => $row->partner_name === null ? null : (string) $row->partner_name,
                'tenant_name' => $row->tenant_name === null ? null : (string) $row->tenant_name,
                'period_from' => $row->period_from === null ? null : (string) $row->period_from,
                'period_to' => $row->period_to === null ? null : (string) $row->period_to,
                'updated_at' => $this->isoDate($row->updated_at),
            ])
            ->all();
    }

    /**
     * @return array<int, array<string, mixed>>
     */
    private function centralDashboardRecentActivity(): array
    {
        if (! $this->tableExists('audit_logs')) {
            return [];
        }

        return DB::table('audit_logs')
            ->where('scope_type', 'central')
            ->whereNull('tenant_id')
            ->select(['id', 'actor_type', 'actor_id', 'action', 'target_type', 'target_id', 'created_at'])
            ->orderByDesc('created_at')
            ->limit(8)
            ->get()
            ->map(fn (object $row): array => [
                'id' => (string) $row->id,
                'actor_type' => (string) $row->actor_type,
                'actor_id' => (string) $row->actor_id,
                'action' => (string) $row->action,
                'target_type' => $row->target_type === null ? null : (string) $row->target_type,
                'target_id' => $row->target_id === null ? null : (string) $row->target_id,
                'created_at' => $this->isoDate($row->created_at),
            ])
            ->all();
    }

    /**
     * @return array<int, array{status: string, label: string, count: int, percent: float}>
     */
    private function statusBreakdown(string $table, string $statusColumn = 'status', ?callable $filter = null): array
    {
        if (! $this->tableExists($table) || ! Schema::hasColumn($table, $statusColumn)) {
            return [];
        }

        $query = DB::table($table);
        if ($filter !== null) {
            $filter($query);
        }

        $rows = $query
            ->select($statusColumn, DB::raw('COUNT(*) as row_count'))
            ->groupBy($statusColumn)
            ->orderByDesc('row_count')
            ->get();

        $total = max(0, (int) $rows->sum(fn (object $row): int => (int) $row->row_count));
        if ($total === 0) {
            return [];
        }

        return $rows
            ->map(fn (object $row): array => [
                'status' => (string) ($row->{$statusColumn} ?? 'unknown'),
                'label' => $this->labelize((string) ($row->{$statusColumn} ?? 'unknown')),
                'count' => (int) $row->row_count,
                'percent' => round(((int) $row->row_count / $total) * 100, 2),
            ])
            ->all();
    }

    private function countTable(string $table, ?callable $filter = null): int
    {
        if (! $this->tableExists($table)) {
            return 0;
        }

        $query = DB::table($table);
        if ($filter !== null) {
            $filter($query);
        }

        return (int) $query->count();
    }

    private function sumTable(string $table, string $column, ?callable $filter = null): int
    {
        if (! $this->tableExists($table) || ! Schema::hasColumn($table, $column)) {
            return 0;
        }

        $query = DB::table($table);
        if ($filter !== null) {
            $filter($query);
        }

        return (int) $query->sum($column);
    }

    private function paidOrdersQuery(): ?\Illuminate\Database\Query\Builder
    {
        if (! $this->tableExists('orders')) {
            return null;
        }

        return DB::table('orders')
            ->where(function ($query): void {
                $query->where('orders.payment_status', 'paid')
                    ->orWhereNotNull('orders.paid_at')
                    ->orWhereIn('orders.status', ['paid', 'completed']);
            });
    }

    private function paidOrdersCount(?string $gameId = null): int
    {
        $query = $this->paidOrdersQuery();
        if ($query === null) {
            return 0;
        }

        if ($gameId !== null) {
            $query->where('game_id', $gameId);
        }

        return (int) $query->count();
    }

    private function paidCustomersCount(?string $gameId = null): int
    {
        $query = $this->paidOrdersQuery();
        if ($query === null || ! Schema::hasColumn('orders', 'customer_id')) {
            return 0;
        }

        if ($gameId !== null) {
            $query->where('game_id', $gameId);
        }

        return (int) $query->whereNotNull('orders.customer_id')->distinct()->count('orders.customer_id');
    }

    private function paidTicketsCount(?string $gameId = null): int
    {
        if (! $this->tableExists('tickets') || ! $this->tableExists('orders')) {
            return 0;
        }

        $query = DB::table('tickets')
            ->join('orders', 'orders.id', '=', 'tickets.order_id')
            ->where(function ($query): void {
                $query->where('orders.payment_status', 'paid')
                    ->orWhereNotNull('orders.paid_at')
                    ->orWhereIn('orders.status', ['paid', 'completed']);
            });

        if ($gameId !== null) {
            $query->where('tickets.game_id', $gameId);
        }

        return (int) $query->count('tickets.id');
    }

    private function paidOrdersSum(string $column, ?string $gameId = null): int
    {
        $query = $this->paidOrdersQuery();
        if ($query === null || ! Schema::hasColumn('orders', $column)) {
            return 0;
        }

        if ($gameId !== null) {
            $query->where('game_id', $gameId);
        }

        return (int) $query->sum($column);
    }

    private function isPaidOrderRow(object $row): bool
    {
        return (string) ($row->payment_status ?? '') === 'paid'
            || ($row->paid_at ?? null) !== null
            || in_array((string) ($row->status ?? ''), ['paid', 'completed'], true);
    }

    /**
     * @return array<int, string>
     */
    private function recentDayKeys(int $days): array
    {
        $start = CarbonImmutable::now()->startOfDay()->subDays($days - 1);
        $keys = [];

        for ($index = 0; $index < $days; $index++) {
            $keys[] = $start->addDays($index)->format('Y-m-d');
        }

        return $keys;
    }

    private function dayKey(mixed $value): string
    {
        return CarbonImmutable::parse($value)->format('Y-m-d');
    }

    private function isoDate(mixed $value): ?string
    {
        if ($value === null || $value === '') {
            return null;
        }

        return CarbonImmutable::parse($value)->toISOString();
    }

    /**
     * @return array{amount: int, currency: string}
     */
    private function money(int $amount, string $currency = 'THB'): array
    {
        return ['amount' => $amount, 'currency' => $currency];
    }

    private function labelize(string $value): string
    {
        return ucwords(str_replace(['_', '-'], ' ', $value));
    }

    private function tableExists(string $table): bool
    {
        return Schema::hasTable($table);
    }

    /**
     * @return array<int, array{key: string, label: string, route: string, icon: string}>
     */
    private function centralDashboardNavigation(): array
    {
        return [
            ['key' => 'sales', 'label' => 'Sales', 'route' => '/admin/central/dashboard/sales', 'icon' => 'ri-line-chart-line'],
            ['key' => 'partner', 'label' => 'Partner', 'route' => '/admin/central/dashboard/partner', 'icon' => 'ri-building-4-line'],
            ['key' => 'wallet', 'label' => 'Wallet', 'route' => '/admin/central/dashboard/wallet', 'icon' => 'ri-wallet-3-line'],
            ['key' => 'payout', 'label' => 'Payout', 'route' => '/admin/central/dashboard/payout', 'icon' => 'ri-bank-card-line'],
            ['key' => 'monitor', 'label' => 'Monitor', 'route' => '/admin/central/dashboard/monitor', 'icon' => 'ri-pulse-line'],
        ];
    }

    private function centralDashboardSectionTitle(string $section): string
    {
        return match ($section) {
            'partner' => 'Partner Dashboard',
            'wallet' => 'Wallet Dashboard',
            'payout' => 'Payout Dashboard',
            'monitor' => 'Monitor Dashboard',
            default => 'Sales Dashboard',
        };
    }

    /**
     * @return array<int, array{key: string, label: string}>
     */
    private function centralDashboardPeriodOptions(string $section = 'sales'): array
    {
        if ($section === 'payout') {
            return [
                ['key' => 'current_draw', 'label' => 'This draw'],
                ['key' => 'previous_draw', 'label' => 'Previous draw'],
                ['key' => 'this_month', 'label' => 'This month'],
                ['key' => 'this_year', 'label' => 'This year'],
            ];
        }

        return [
            ['key' => 'today', 'label' => 'Today'],
            ['key' => 'yesterday', 'label' => 'Yesterday'],
            ['key' => 'last_7_days', 'label' => 'Last 7 days'],
            ['key' => 'previous_draw', 'label' => 'Previous draw'],
        ];
    }

    /**
     * @return array<string, mixed>
     */
    private function centralDashboardPeriod(string $period, string $section = 'sales'): array
    {
        if ($section === 'payout') {
            return $this->centralPayoutDashboardPeriod($period);
        }

        $key = in_array($period, ['today', 'yesterday', 'last_7_days', 'previous_draw'], true) ? $period : 'today';
        $now = CarbonImmutable::now();

        if ($key === 'previous_draw') {
            $currentGame = $this->centralDashboardPreviousGameRow($this->centralDashboardCurrentGameRow());
            $previousGame = $this->centralDashboardPreviousGameRow($currentGame);
            $currentStart = $currentGame?->sale_start_at !== null ? CarbonImmutable::parse($currentGame->sale_start_at) : $now->startOfDay()->subDays(16);
            $currentEnd = $currentGame?->close_at !== null ? CarbonImmutable::parse($currentGame->close_at) : ($currentGame?->draw_at !== null ? CarbonImmutable::parse($currentGame->draw_at) : $now);
            $previousStart = $previousGame?->sale_start_at !== null ? CarbonImmutable::parse($previousGame->sale_start_at) : $currentStart->subDays(16);
            $previousEnd = $previousGame?->close_at !== null ? CarbonImmutable::parse($previousGame->close_at) : ($previousGame?->draw_at !== null ? CarbonImmutable::parse($previousGame->draw_at) : $currentStart);

            return [
                'key' => $key,
                'label' => 'Previous draw',
                'current_label' => $currentGame?->draw_at !== null ? CarbonImmutable::parse($currentGame->draw_at)->format('d M Y') : 'Previous draw',
                'previous_label' => $previousGame?->draw_at !== null ? CarbonImmutable::parse($previousGame->draw_at)->format('d M Y') : 'Prior draw',
                'current_start' => $currentStart,
                'current_end' => $currentEnd,
                'previous_start' => $previousStart,
                'previous_end' => $previousEnd,
                'game_id' => $currentGame?->id === null ? null : (string) $currentGame->id,
                'previous_game_id' => $previousGame?->id === null ? null : (string) $previousGame->id,
            ];
        }

        if ($key === 'yesterday') {
            $currentStart = $now->subDay()->startOfDay();
            $currentEnd = $now->subDay()->endOfDay();
            $previousStart = $now->subDays(2)->startOfDay();
            $previousEnd = $now->subDays(2)->endOfDay();
        } elseif ($key === 'last_7_days') {
            $currentStart = $now->subDays(6)->startOfDay();
            $currentEnd = $now->endOfDay();
            $previousStart = $currentStart->subDays(7);
            $previousEnd = $currentStart->subSecond();
        } else {
            $currentStart = $now->startOfDay();
            $currentEnd = $now;
            $previousStart = $now->subDay()->startOfDay();
            $previousEnd = $now->subDay();
        }

        return [
            'key' => $key,
            'label' => match ($key) {
                'yesterday' => 'Yesterday',
                'last_7_days' => 'Last 7 days',
                default => 'Today',
            },
            'current_label' => match ($key) {
                'yesterday' => 'Yesterday',
                'last_7_days' => $currentStart->format('d M').' - '.$currentEnd->format('d M Y'),
                default => 'Today',
            },
            'previous_label' => match ($key) {
                'last_7_days' => $previousStart->format('d M').' - '.$previousEnd->format('d M Y'),
                default => 'Previous period',
            },
            'current_start' => $currentStart,
            'current_end' => $currentEnd,
            'previous_start' => $previousStart,
            'previous_end' => $previousEnd,
            'game_id' => null,
            'previous_game_id' => null,
        ];
    }

    /**
     * @return array<string, mixed>
     */
    private function centralPayoutDashboardPeriod(string $period): array
    {
        $key = in_array($period, ['current_draw', 'previous_draw', 'this_month', 'this_year'], true) ? $period : 'current_draw';
        $now = CarbonImmutable::now();

        if ($key === 'current_draw') {
            return $this->centralDashboardGameWindow(
                $key,
                'This draw',
                $this->centralDashboardCurrentGameRow(),
                'Current draw',
                $now,
            );
        }

        if ($key === 'previous_draw') {
            return $this->centralDashboardGameWindow(
                $key,
                'Previous draw',
                $this->centralDashboardPreviousGameRow($this->centralDashboardCurrentGameRow()),
                'Previous draw',
                $now,
            );
        }

        if ($key === 'this_year') {
            $currentStart = $now->startOfYear();
            $currentEnd = $now->endOfDay();
            $previousStart = $currentStart->subYear();
            $previousEnd = $now->subYear()->endOfDay();

            return [
                'key' => $key,
                'label' => 'This year',
                'current_label' => $currentStart->format('Y'),
                'previous_label' => $previousStart->format('Y'),
                'current_start' => $currentStart,
                'current_end' => $currentEnd,
                'previous_start' => $previousStart,
                'previous_end' => $previousEnd,
                'game_id' => null,
                'previous_game_id' => null,
            ];
        }

        $currentStart = $now->startOfMonth();
        $currentEnd = $now->endOfDay();
        $previousStart = $currentStart->subMonthNoOverflow();
        $previousEnd = $previousStart->endOfMonth();

        return [
            'key' => $key,
            'label' => 'This month',
            'current_label' => $currentStart->format('M Y'),
            'previous_label' => $previousStart->format('M Y'),
            'current_start' => $currentStart,
            'current_end' => $currentEnd,
            'previous_start' => $previousStart,
            'previous_end' => $previousEnd,
            'game_id' => null,
            'previous_game_id' => null,
        ];
    }

    /**
     * @return array<string, mixed>
     */
    private function centralDashboardGameWindow(string $key, string $label, ?object $currentGame, string $fallbackLabel, CarbonImmutable $now): array
    {
        $previousGame = $this->centralDashboardPreviousGameRow($currentGame);
        $currentStart = $currentGame?->sale_start_at !== null ? CarbonImmutable::parse($currentGame->sale_start_at) : $now->startOfDay()->subDays(16);
        $currentEnd = $currentGame?->close_at !== null ? CarbonImmutable::parse($currentGame->close_at) : ($currentGame?->draw_at !== null ? CarbonImmutable::parse($currentGame->draw_at) : $now);
        $previousStart = $previousGame?->sale_start_at !== null ? CarbonImmutable::parse($previousGame->sale_start_at) : $currentStart->subDays(16);
        $previousEnd = $previousGame?->close_at !== null ? CarbonImmutable::parse($previousGame->close_at) : ($previousGame?->draw_at !== null ? CarbonImmutable::parse($previousGame->draw_at) : $currentStart);

        return [
            'key' => $key,
            'label' => $label,
            'current_label' => $currentGame?->draw_at !== null ? CarbonImmutable::parse($currentGame->draw_at)->format('d M Y') : $fallbackLabel,
            'previous_label' => $previousGame?->draw_at !== null ? CarbonImmutable::parse($previousGame->draw_at)->format('d M Y') : 'Prior draw',
            'current_start' => $currentStart,
            'current_end' => $currentEnd,
            'previous_start' => $previousStart,
            'previous_end' => $previousEnd,
            'game_id' => $currentGame?->id === null ? null : (string) $currentGame->id,
            'previous_game_id' => $previousGame?->id === null ? null : (string) $previousGame->id,
        ];
    }

    /**
     * @param array<string, mixed> $window
     * @return array<string, mixed>
     */
    private function centralSalesDashboard(array $window): array
    {
        $sales = $this->ordersSumForWindow($window, 'total_amount');
        $previousSales = $this->ordersSumForWindow($window, 'total_amount', previous: true);
        $orders = $this->ordersCountForWindow($window);
        $previousOrders = $this->ordersCountForWindow($window, previous: true);
        $tickets = $this->ticketsCountForWindow($window);
        $previousTickets = $this->ticketsCountForWindow($window, previous: true);
        $customers = $this->ordersCustomerCountForWindow($window);
        $previousCustomers = $this->ordersCustomerCountForWindow($window, previous: true);
        $partners = $this->ordersPartnerCountForWindow($window);
        $previousPartners = $this->ordersPartnerCountForWindow($window, previous: true);

        return [
            'hero' => [
                'label' => 'Paid sales',
                'value' => $this->money($sales),
                'previous' => $this->money($previousSales),
                'delta' => $this->dashboardDelta($sales, $previousSales),
                'caption' => 'Lottery revenue across all partners.',
            ],
            'metrics' => [
                $this->dashboardMetric('sales_amount', 'Paid sales', 'money', $sales, $previousSales, 'ri-money-dollar-circle-line', 'primary'),
                $this->dashboardMetric('tickets_sold', 'Tickets sold', 'number', $tickets, $previousTickets, 'ri-ticket-2-line', 'success'),
                $this->dashboardMetric('paid_orders', 'Paid orders', 'number', $orders, $previousOrders, 'ri-shopping-bag-3-line', 'info'),
                $this->dashboardMetric('average_order', 'Average order', 'money', $orders > 0 ? (int) round($sales / $orders) : 0, $previousOrders > 0 ? (int) round($previousSales / $previousOrders) : 0, 'ri-bar-chart-grouped-line', 'warning'),
                $this->dashboardMetric('paid_customers', 'Paid customers', 'number', $customers, $previousCustomers, 'ri-user-heart-line', 'secondary'),
                $this->dashboardMetric('selling_partners', 'Selling partners', 'number', $partners, $previousPartners, 'ri-building-4-line', 'pink'),
            ],
            'charts' => [
                'primary_trend' => $this->salesTrendForWindow($window),
                'sales_ticket_comparison' => $this->salesTicketComparisonForWindow($window),
                'secondary_breakdown' => $this->ordersPaymentMethodBreakdown($window),
                'top_entities' => $this->topPartnersBySales($window),
            ],
            'tables' => [
                'top_partners' => $this->topPartnersBySales($window, 8),
                'top_tenants' => $this->topTenantsBySales($window, 8),
                'popular_numbers' => $this->popularLotteryNumbersForWindow($window),
                'set_distribution' => $this->stockSetDistributionForWindow($window),
                'recent_rows' => $this->recentOrdersForWindow($window),
            ],
        ];
    }

    /**
     * @param array<string, mixed> $window
     * @return array<string, mixed>
     */
    private function centralPartnerDashboard(array $window): array
    {
        $partners = $this->countForWindow('partners', $window);
        $previousPartners = $this->countForWindow('partners', $window, previous: true);
        $affiliateAccounts = $this->countForWindow('affiliate_accounts', $window);
        $previousAffiliateAccounts = $this->countForWindow('affiliate_accounts', $window, previous: true);
        $newAffiliateAccounts = $this->countForWindow('affiliate_accounts', $window);
        $previousNewAffiliateAccounts = $this->countForWindow('affiliate_accounts', $window, previous: true);
        $sales = $this->ordersSumForWindow($window, 'total_amount');
        $previousSales = $this->ordersSumForWindow($window, 'total_amount', previous: true);
        $tickets = $this->ticketsCountForWindow($window);
        $previousTickets = $this->ticketsCountForWindow($window, previous: true);
        $partnerSalesComparison = $this->partnerSalesComparisonForWindow($window);
        $partnerNewMembersComparison = $this->partnerNewMembersComparisonForWindow($window);
        $partnerAffiliateAccountsComparison = $this->partnerAffiliateAccountsComparisonForWindow($window);

        return [
            'hero' => [
                'label' => 'Partner sales',
                'value' => $this->money($sales),
                'previous' => $this->money($previousSales),
                'delta' => $this->dashboardDelta($sales, $previousSales),
                'caption' => 'Sales movement, member growth, and affiliate contribution.',
            ],
            'metrics' => [
                $this->dashboardMetric('partner_sales_amount', 'ยอดขาย Partner ทั้งหมด', 'money', $sales, $previousSales, 'ri-money-dollar-circle-line', 'primary'),
                $this->dashboardMetric('partner_sales_tickets', 'ยอดขาย Partner ทั้งหมด', 'number', $tickets, $previousTickets, 'ri-ticket-2-line', 'success'),
                $this->dashboardMetric('new_partners', 'Partner ใหม่', 'number', $partners, $previousPartners, 'ri-building-4-line', 'info'),
                $this->dashboardMetric('affiliate_accounts', 'Affiliate Account', 'number', $affiliateAccounts, $previousAffiliateAccounts, 'ri-team-line', 'warning'),
                $this->dashboardMetric('new_affiliate_accounts', 'New Affiliate Account', 'number', $newAffiliateAccounts, $previousNewAffiliateAccounts, 'ri-user-follow-line', 'secondary'),
            ],
            'charts' => [
                'primary_trend' => $this->partnerGrowthTrendForWindow($window),
                'secondary_breakdown' => $this->affiliateStatusBreakdown($window),
                'top_entities' => $this->topPartnersBySales($window),
                'partner_sales_comparison' => $partnerSalesComparison,
                'partner_new_members_comparison' => $partnerNewMembersComparison,
                'partner_affiliate_accounts_comparison' => $partnerAffiliateAccountsComparison,
            ],
            'tables' => [
                'top_partners' => $this->topPartnersBySales($window, 10),
                'top_tenants' => $this->topTenantsBySales($window, 10),
                'partner_sales' => $partnerSalesComparison['rows'],
                'partner_members' => $partnerNewMembersComparison['rows'],
                'partner_affiliates' => $partnerAffiliateAccountsComparison['rows'],
                'recent_rows' => $this->recentPartnersForWindow($window),
            ],
        ];
    }

    /**
     * @param array<string, mixed> $window
     * @return array<string, mixed>
     */
    private function centralWalletDashboard(array $window): array
    {
        $credit = $this->walletLedgerFlowAmount($window, 'inflow');
        $previousCredit = $this->walletLedgerFlowAmount($window, 'inflow', previous: true);
        $debit = $this->walletLedgerFlowAmount($window, 'outflow');
        $previousDebit = $this->walletLedgerFlowAmount($window, 'outflow', previous: true);
        $topup = $this->sumForWindow('topup_requests', 'amount', $window);
        $previousTopup = $this->sumForWindow('topup_requests', 'amount', $window, previous: true);
        $payments = $this->sumForWindow('payments', 'amount', $window, column: 'paid_at');
        $previousPayments = $this->sumForWindow('payments', 'amount', $window, previous: true, column: 'paid_at');
        $balance = $this->sumTable('wallets', 'balance_amount', fn ($query) => $query->where('status', 'active'));

        return [
            'hero' => [
                'label' => 'Wallet flow',
                'value' => $this->money($credit - $debit),
                'previous' => $this->money($previousCredit - $previousDebit),
                'delta' => $this->dashboardDelta($credit - $debit, $previousCredit - $previousDebit),
                'caption' => 'Net money movement through wallets and payment channels.',
            ],
            'metrics' => [
                $this->dashboardMetric('wallet_balance', 'Wallet balance', 'money', $balance, null, 'ri-wallet-3-line', 'primary'),
                $this->dashboardMetric('wallet_inflow', 'Wallet inflow', 'money', $credit, $previousCredit, 'ri-arrow-down-circle-line', 'success'),
                $this->dashboardMetric('wallet_outflow', 'Wallet outflow', 'money', $debit, $previousDebit, 'ri-arrow-up-circle-line', 'danger'),
                $this->dashboardMetric('topups', 'Topups', 'money', $topup, $previousTopup, 'ri-bank-card-line', 'info'),
                $this->dashboardMetric('payment_volume', 'Payment volume', 'money', $payments, $previousPayments, 'ri-secure-payment-line', 'warning'),
            ],
            'charts' => [
                'primary_trend' => $this->walletFlowTrendForWindow($window),
                'secondary_breakdown' => $this->topupChannelBreakdown($window),
                'top_entities' => $this->paymentProviderBreakdown($window),
            ],
            'tables' => [
                'top_partners' => $this->topTenantsByWalletFlow($window, 8),
                'top_tenants' => $this->paymentProviderBreakdown($window),
                'recent_rows' => $this->recentWalletLedgerForWindow($window),
            ],
        ];
    }

    /**
     * @param array<string, mixed> $window
     * @return array<string, mixed>
     */
    private function centralPayoutDashboard(array $window): array
    {
        $winningAmount = $this->sumForWindow('winning_tickets', 'amount', $window, gameColumn: 'game_id');
        $previousWinningAmount = $this->sumForWindow('winning_tickets', 'amount', $window, previous: true, gameColumn: 'game_id');
        $winningTickets = $this->countForWindow('winning_tickets', $window, gameColumn: 'game_id');
        $previousWinningTickets = $this->countForWindow('winning_tickets', $window, previous: true, gameColumn: 'game_id');
        $claimPayout = $this->sumForWindow('reward_claims', 'prize_amount', $window, column: 'paid_at', gameColumn: 'game_id');
        $previousClaimPayout = $this->sumForWindow('reward_claims', 'prize_amount', $window, previous: true, column: 'paid_at', gameColumn: 'game_id');
        $pendingClaims = $this->countTable('reward_claims', fn ($query) => $query->whereIn('status', ['submitted', 'under_review']));
        $commissions = $this->sumForWindow('commission_transactions', 'amount', $window, column: 'approved_at');
        $previousCommissions = $this->sumForWindow('commission_transactions', 'amount', $window, previous: true, column: 'approved_at');
        $affiliatePayouts = $this->sumForWindow('affiliate_payouts', 'amount', $window, column: 'approved_at');
        $previousAffiliatePayouts = $this->sumForWindow('affiliate_payouts', 'amount', $window, previous: true, column: 'approved_at');
        $partnerPayoutRows = $this->topPartnersByPayout($window, 100);
        $partnerCommissionRows = $this->topPartnersByCommission($window, 100);

        return [
            'hero' => [
                'label' => 'Reward payouts',
                'value' => $this->money($claimPayout),
                'previous' => $this->money($previousClaimPayout),
                'delta' => $this->dashboardDelta($claimPayout, $previousClaimPayout),
                'caption' => 'Prize claims, winning liabilities, commissions, and partner payouts.',
            ],
            'metrics' => [
                $this->dashboardMetric('reward_payouts', 'Reward payouts', 'money', $claimPayout, $previousClaimPayout, 'ri-trophy-line', 'primary'),
                $this->dashboardMetric('winning_liability', 'Winning liability', 'money', $winningAmount, $previousWinningAmount, 'ri-award-line', 'warning'),
                $this->dashboardMetric('winning_tickets', 'Winning tickets', 'number', $winningTickets, $previousWinningTickets, 'ri-ticket-2-line', 'success'),
                $this->dashboardMetric('pending_claims', 'Pending claims', 'number', $pendingClaims, null, 'ri-time-line', 'danger'),
                $this->dashboardMetric('commissions', 'Commissions', 'money', $commissions + $affiliatePayouts, $previousCommissions + $previousAffiliatePayouts, 'ri-team-line', 'info'),
                $this->dashboardMetric('commission_transactions', 'Commission transactions', 'money', $commissions, $previousCommissions, 'ri-exchange-dollar-line', 'secondary'),
                $this->dashboardMetric('affiliate_payouts', 'Affiliate payouts', 'money', $affiliatePayouts, $previousAffiliatePayouts, 'ri-bank-card-line', 'pink'),
            ],
            'charts' => [
                'primary_trend' => $this->payoutTrendForWindow($window),
                'secondary_breakdown' => $this->rewardClaimStatusBreakdown($window),
                'top_entities' => $this->rewardPayoutMethodBreakdown($window),
                'partner_payout_comparison' => [
                    'labels' => array_map(fn (array $row): string => (string) $row['name'], $partnerPayoutRows),
                    'type' => 'money',
                    'rows' => $partnerPayoutRows,
                ],
                'winning_type_breakdown' => $this->winningPrizeTypeBreakdown($window),
                'partner_commission_comparison' => [
                    'labels' => array_map(fn (array $row): string => (string) $row['name'], $partnerCommissionRows),
                    'type' => 'money',
                    'rows' => $partnerCommissionRows,
                ],
            ],
            'tables' => [
                'top_partners' => $partnerPayoutRows,
                'top_tenants' => $this->rewardPayoutMethodBreakdown($window),
                'recent_rows' => $this->recentRewardClaimsForWindow($window),
                'commission_partners' => $partnerCommissionRows,
            ],
        ];
    }

    /**
     * @param array<string, mixed> $window
     * @return array<string, mixed>
     */
    private function centralMonitorDashboard(array $window): array
    {
        $activeMembers = $this->monitorCustomerSessionsCount($window);
        $previousActiveMembers = $this->monitorCustomerSessionsCount($window, previous: true);
        $activeGuests = $this->monitorPublicVisitSessionsCount($window, true);
        $previousActiveGuests = $this->monitorPublicVisitSessionsCount($window, true, previous: true);
        $activeAdmins = $this->monitorAdminSessionsCount($window);
        $previousActiveAdmins = $this->monitorAdminSessionsCount($window, previous: true);
        $activeOwners = $this->monitorOwnerPartnerSessionsCount($window);
        $previousActiveOwners = $this->monitorOwnerPartnerSessionsCount($window, previous: true);
        $activeTenants = $this->monitorTenantsCount($window);
        $previousActiveTenants = $this->monitorTenantsCount($window, previous: true);
        $memberGrowth = $this->countForWindow('customers', $window);
        $previousMemberGrowth = $this->countForWindow('customers', $window, previous: true);
        $onlineTotal = $activeMembers + $activeGuests + $activeAdmins;
        $previousOnlineTotal = $previousActiveMembers + $previousActiveGuests + $previousActiveAdmins;
        $notes = [];

        if (! $this->tableExists('public_visit_sessions')) {
            $notes['guest_sessions'] = 'Public visitor tracking table is not migrated yet; guest/source metrics will appear after migration.';
        }

        return [
            'hero' => [
                'label' => 'Online usage',
                'value' => $onlineTotal,
                'previous' => $previousOnlineTotal,
                'delta' => $this->dashboardDelta($onlineTotal, $previousOnlineTotal),
                'caption' => 'Member, guest, and admin activity in the selected filter period.',
            ],
            'metrics' => [
                $this->dashboardMetric('active_members', 'Online members', 'number', $activeMembers, $previousActiveMembers, 'ri-user-heart-line', 'primary'),
                $this->dashboardMetric('active_guests', 'Online guests', 'number', $activeGuests, $previousActiveGuests, 'ri-user-search-line', 'secondary'),
                $this->dashboardMetric('active_admins', 'Online admins', 'number', $activeAdmins, $previousActiveAdmins, 'ri-shield-user-line', 'success'),
                $this->dashboardMetric('active_owner_partners', 'Online partner owners', 'number', $activeOwners, $previousActiveOwners, 'ri-building-4-line', 'info'),
                $this->dashboardMetric('active_tenants', 'Active partner stores', 'number', $activeTenants, $previousActiveTenants, 'ri-store-2-line', 'warning'),
                $this->dashboardMetric('member_growth', 'Member growth', 'number', $memberGrowth, $previousMemberGrowth, 'ri-user-add-line', 'secondary'),
            ],
            'charts' => [
                'primary_trend' => $this->sessionTrendForWindow($window),
                'secondary_breakdown' => $this->monitorSourceBreakdown($window),
                'top_entities' => $this->monitorTenantsBreakdown($window),
            ],
            'tables' => [
                'top_partners' => $this->monitorTenantsBreakdown($window, 8),
                'top_tenants' => $this->recentVisitorIpsForWindow($window),
                'recent_rows' => $this->monitorAdminSessions($window),
                'members' => $this->monitorCustomerSessions($window),
                'visitors' => $this->monitorPublicVisitSessions($window),
            ],
            'notes' => $notes,
        ];
    }

    private function dashboardMetric(string $key, string $label, string $type, ?int $current, ?int $previous, string $icon, string $tone): array
    {
        return [
            'key' => $key,
            'label' => $label,
            'type' => $type,
            'current' => $current ?? 0,
            'previous' => $previous,
            'delta' => $this->dashboardDelta($current ?? 0, $previous),
            'icon' => $icon,
            'tone' => $tone,
        ];
    }

    private function dashboardDelta(int $current, ?int $previous): array
    {
        if ($previous === null) {
            return ['amount' => null, 'percent' => null, 'direction' => 'flat'];
        }

        $amount = $current - $previous;

        return [
            'amount' => $amount,
            'percent' => $previous === 0 ? null : round(($amount / $previous) * 100, 2),
            'direction' => $amount === 0 ? 'flat' : ($amount > 0 ? 'up' : 'down'),
        ];
    }

    private function ordersForWindow(array $window, bool $previous = false): ?\Illuminate\Database\Query\Builder
    {
        $query = $this->paidOrdersQuery();
        if ($query === null) {
            return null;
        }

        $gameId = $previous ? $window['previous_game_id'] : $window['game_id'];
        if ($gameId !== null) {
            $query->where('orders.game_id', $gameId);
        } else {
            $this->applyTimeWindow($query, $window, 'orders.paid_at', $previous, 'orders.created_at');
        }

        return $query;
    }

    private function ordersSumForWindow(array $window, string $column, bool $previous = false): int
    {
        $query = $this->ordersForWindow($window, $previous);

        return $query === null || ! Schema::hasColumn('orders', $column) ? 0 : (int) $query->sum('orders.'.$column);
    }

    private function ordersCountForWindow(array $window, bool $previous = false): int
    {
        $query = $this->ordersForWindow($window, $previous);

        return $query === null ? 0 : (int) $query->count();
    }

    private function ordersCustomerCountForWindow(array $window, bool $previous = false): int
    {
        $query = $this->ordersForWindow($window, $previous);

        return $query === null ? 0 : (int) $query->whereNotNull('orders.customer_id')->distinct()->count('orders.customer_id');
    }

    private function ordersPartnerCountForWindow(array $window, bool $previous = false): int
    {
        if (! $this->tableExists('partner_tenants')) {
            return 0;
        }

        $query = $this->ordersForWindow($window, $previous);
        if ($query === null) {
            return 0;
        }

        return (int) $query
            ->join('partner_tenants', 'partner_tenants.id', '=', 'orders.tenant_id')
            ->whereNotNull('partner_tenants.partner_id')
            ->distinct()
            ->count('partner_tenants.partner_id');
    }

    private function ticketsCountForWindow(array $window, bool $previous = false): int
    {
        if (! $this->tableExists('tickets') || ! $this->tableExists('orders')) {
            return 0;
        }

        $query = DB::table('tickets')
            ->join('orders', 'orders.id', '=', 'tickets.order_id')
            ->where(function ($query): void {
                $query->where('orders.payment_status', 'paid')
                    ->orWhereNotNull('orders.paid_at')
                    ->orWhereIn('orders.status', ['paid', 'completed']);
            });

        $gameId = $previous ? $window['previous_game_id'] : $window['game_id'];
        if ($gameId !== null) {
            $query->where('tickets.game_id', $gameId);
        } else {
            $this->applyTimeWindow($query, $window, 'orders.paid_at', $previous, 'orders.created_at');
        }

        return (int) $query->count('tickets.id');
    }

    private function countForWindow(string $table, array $window, bool $previous = false, string $column = 'created_at', ?string $gameColumn = null): int
    {
        if (! $this->tableExists($table) || ! Schema::hasColumn($table, $column)) {
            return 0;
        }

        $query = DB::table($table);
        $gameId = $previous ? $window['previous_game_id'] : $window['game_id'];
        if ($gameColumn !== null && $gameId !== null && Schema::hasColumn($table, $gameColumn)) {
            $query->where($gameColumn, $gameId);
        } else {
            $this->applyTimeWindow($query, $window, $table.'.'.$column, $previous);
        }

        return (int) $query->count();
    }

    private function countUntil(string $table, array $window, bool $previous = false, string $column = 'created_at'): int
    {
        if (! $this->tableExists($table) || ! Schema::hasColumn($table, $column)) {
            return 0;
        }

        $end = $previous ? $window['previous_end'] : $window['current_end'];

        return (int) DB::table($table)
            ->where($table.'.'.$column, '<=', $end)
            ->count();
    }

    private function sumForWindow(string $table, string $amountColumn, array $window, bool $previous = false, string $column = 'created_at', ?string $gameColumn = null): int
    {
        if (! $this->tableExists($table) || ! Schema::hasColumn($table, $amountColumn) || ! Schema::hasColumn($table, $column)) {
            return 0;
        }

        $query = DB::table($table);
        $gameId = $previous ? $window['previous_game_id'] : $window['game_id'];
        if ($gameColumn !== null && $gameId !== null && Schema::hasColumn($table, $gameColumn)) {
            $query->where($gameColumn, $gameId);
        } else {
            $this->applyTimeWindow($query, $window, $table.'.'.$column, $previous, $column === 'created_at' ? null : $table.'.created_at');
        }

        return (int) $query->sum($amountColumn);
    }

    private function applyTimeWindow(\Illuminate\Database\Query\Builder $query, array $window, string $column, bool $previous = false, ?string $fallbackColumn = null): void
    {
        $start = $previous ? $window['previous_start'] : $window['current_start'];
        $end = $previous ? $window['previous_end'] : $window['current_end'];
        $expression = $fallbackColumn === null ? $column : 'COALESCE('.$column.', '.$fallbackColumn.')';

        $query->whereRaw($expression.' >= ? and '.$expression.' <= ?', [$start, $end]);
    }

    private function walletLedgerFlowAmount(array $window, string $direction, bool $previous = false): int
    {
        if (! $this->tableExists('wallet_ledger')) {
            return 0;
        }

        $query = DB::table('wallet_ledger');
        $this->applyTimeWindow($query, $window, 'wallet_ledger.posted_at', $previous, 'wallet_ledger.created_at');

        if (Schema::hasColumn('wallet_ledger', 'entry_type')) {
            if ($direction === 'outflow') {
                $query->whereIn('entry_type', ['debit', 'hold']);
            } else {
                $query->whereNotIn('entry_type', ['debit', 'hold']);
            }

            return (int) $query->sum(DB::raw('ABS(amount)'));
        }

        if ($direction === 'outflow') {
            $query->where('amount', '<', 0);

            return abs((int) $query->sum('amount'));
        }

        $query->where('amount', '>', 0);

        return (int) $query->sum('amount');
    }

    /**
     * @return array<string, mixed>
     */
    private function salesTrendForWindow(array $window): array
    {
        return $this->dailyTrend($window, [
            ['key' => 'sales_amount', 'label' => 'Sales', 'type' => 'money', 'table' => 'orders', 'amount' => 'total_amount', 'date' => 'paid_at', 'paid_orders' => true],
            ['key' => 'paid_orders', 'label' => 'Paid orders', 'table' => 'orders', 'date' => 'paid_at', 'paid_orders' => true],
            ['key' => 'tickets_sold', 'label' => 'Tickets', 'table' => 'tickets', 'date' => 'created_at'],
        ]);
    }

    private function salesTicketComparisonForWindow(array $window): array
    {
        $currentGame = $this->salesComparisonCurrentGame($window);
        $previousGame = $this->salesComparisonPreviousGame($window, $currentGame);

        if ($currentGame !== null && $previousGame !== null) {
            $entries = $this->salesComparisonDayEntries($window, $currentGame);
            $currentDateKeys = array_column($entries, 'current_date');
            $previousDateKeys = $this->salesComparisonPreviousDateKeys($entries, $previousGame);

            return [
                'comparison_mode' => 'sale_day',
                'labels' => array_map(fn (array $entry): string => 'Sale day '.$entry['sale_day'], $entries),
                'keys' => array_map(fn (array $entry): string => 'sale_day_'.$entry['sale_day'], $entries),
                'current_dates' => $currentDateKeys,
                'previous_dates' => $previousDateKeys,
                'current_date_labels' => array_map(fn (string $day): string => CarbonImmutable::parse($day)->format('d M'), $currentDateKeys),
                'previous_date_labels' => array_map(fn (string $day): string => CarbonImmutable::parse($day)->format('d M'), $previousDateKeys),
                'series' => [
                    [
                        'key' => 'tickets_sold_current',
                        'label' => $this->dashboardGameSeriesLabel($currentGame, (string) ($window['current_label'] ?? 'Current draw')),
                        'type' => 'number',
                        'values' => $this->ticketTrendValuesForGameDates((string) $currentGame->id, $currentDateKeys),
                    ],
                    [
                        'key' => 'tickets_sold_previous',
                        'label' => $this->dashboardGameSeriesLabel($previousGame, (string) ($window['previous_label'] ?? 'Previous draw')),
                        'type' => 'number',
                        'values' => $this->ticketTrendValuesForGameDates((string) $previousGame->id, $previousDateKeys),
                    ],
                ],
            ];
        }

        $currentKeys = $this->dashboardDateKeys($window, false);
        $previousKeys = $this->dashboardDateKeys($window, true, count($currentKeys));

        return [
            'comparison_mode' => 'calendar',
            'labels' => array_map(fn (string $day): string => CarbonImmutable::parse($day)->format('d M'), $currentKeys),
            'keys' => $currentKeys,
            'previous_labels' => array_map(fn (string $day): string => CarbonImmutable::parse($day)->format('d M'), $previousKeys),
            'series' => [
                [
                    'key' => 'tickets_sold_current',
                    'label' => (string) ($window['current_label'] ?? 'Current'),
                    'type' => 'number',
                    'values' => $this->ticketTrendValues($window, $currentKeys, false),
                ],
                [
                    'key' => 'tickets_sold_previous',
                    'label' => (string) ($window['previous_label'] ?? 'Previous'),
                    'type' => 'number',
                    'values' => $this->ticketTrendValues($window, $previousKeys, true),
                ],
            ],
        ];
    }

    private function salesComparisonCurrentGame(array $window): ?object
    {
        $gameId = $window['game_id'] ?? null;
        if (is_string($gameId) && $gameId !== '') {
            return $this->centralDashboardGameById($gameId);
        }

        return $this->centralDashboardCurrentGameRow();
    }

    private function salesComparisonPreviousGame(array $window, ?object $currentGame): ?object
    {
        $gameId = $window['previous_game_id'] ?? null;
        if (is_string($gameId) && $gameId !== '') {
            return $this->centralDashboardGameById($gameId);
        }

        return $this->centralDashboardPreviousGameRow($currentGame);
    }

    private function centralDashboardGameById(string $gameId): ?object
    {
        if (! $this->tableExists('games')) {
            return null;
        }

        return DB::table('games')->where('id', $gameId)->first();
    }

    /**
     * @return array<int, array{sale_day: int, current_date: string}>
     */
    private function salesComparisonDayEntries(array $window, object $currentGame): array
    {
        $saleStart = $this->gameSaleStartDay($currentGame);
        $saleEnd = $this->gameSaleEndDay($currentGame);

        if (($window['key'] ?? null) === 'previous_draw') {
            $start = $saleStart;
            $end = $saleEnd;
        } else {
            $start = CarbonImmutable::parse($window['current_start'])->startOfDay();
            $end = CarbonImmutable::parse($window['current_end'])->startOfDay();

            if ($start->lessThan($saleStart)) {
                $start = $saleStart;
            }
            if ($end->lessThan($saleStart)) {
                $end = $saleStart;
            }
            if ($start->greaterThan($saleEnd)) {
                $start = $saleEnd;
            }
            if ($end->greaterThan($saleEnd)) {
                $end = $saleEnd;
            }
        }

        if ($end->lessThan($start)) {
            $end = $start;
        }

        $days = max(1, min(31, (int) $start->diffInDays($end) + 1));
        $entries = [];
        for ($index = 0; $index < $days; $index++) {
            $currentDay = $start->addDays($index)->startOfDay();
            $entries[] = [
                'sale_day' => $this->saleDayNumber($saleStart, $currentDay),
                'current_date' => $currentDay->format('Y-m-d'),
            ];
        }

        return $entries;
    }

    /**
     * @param array<int, array{sale_day: int, current_date: string}> $entries
     * @return array<int, string>
     */
    private function salesComparisonPreviousDateKeys(array $entries, object $previousGame): array
    {
        $previousSaleStart = $this->gameSaleStartDay($previousGame);

        return array_map(
            fn (array $entry): string => $previousSaleStart->addDays(max(0, $entry['sale_day'] - 1))->format('Y-m-d'),
            $entries,
        );
    }

    private function gameSaleStartDay(object $game): CarbonImmutable
    {
        $value = $game->sale_start_at ?? $game->created_at ?? $game->draw_at ?? now();

        return CarbonImmutable::parse($value)->startOfDay();
    }

    private function gameSaleEndDay(object $game): CarbonImmutable
    {
        $value = $game->close_at ?? $game->draw_at ?? null;
        if ($value === null || $value === '') {
            return $this->gameSaleStartDay($game)->addDays(15)->startOfDay();
        }

        return CarbonImmutable::parse($value)->startOfDay();
    }

    private function saleDayNumber(CarbonImmutable $saleStart, CarbonImmutable $day): int
    {
        $seconds = $day->startOfDay()->getTimestamp() - $saleStart->startOfDay()->getTimestamp();

        return intdiv(max(0, $seconds), 86400) + 1;
    }

    private function dashboardGameSeriesLabel(object $game, string $fallback): string
    {
        $drawAt = $game->draw_at ?? null;
        if ($drawAt !== null && $drawAt !== '') {
            return CarbonImmutable::parse($drawAt)->format('d M Y');
        }

        return ($game->code ?? null) !== null ? (string) $game->code : $fallback;
    }

    /**
     * @param array<int, string> $dateKeys
     * @return array<int, int>
     */
    private function ticketTrendValuesForGameDates(string $gameId, array $dateKeys): array
    {
        $values = array_fill_keys($dateKeys, 0);

        if ($dateKeys === [] || ! $this->tableExists('tickets') || ! $this->tableExists('orders')) {
            return array_values($values);
        }

        $start = CarbonImmutable::parse(min($dateKeys))->startOfDay();
        $end = CarbonImmutable::parse(max($dateKeys))->endOfDay();

        $rows = DB::table('tickets')
            ->join('orders', 'orders.id', '=', 'tickets.order_id')
            ->where('tickets.game_id', $gameId)
            ->where(function ($query): void {
                $query->where('orders.payment_status', 'paid')
                    ->orWhereNotNull('orders.paid_at')
                    ->orWhereIn('orders.status', ['paid', 'completed']);
            })
            ->whereRaw('COALESCE(orders.paid_at, orders.created_at) >= ? and COALESCE(orders.paid_at, orders.created_at) <= ?', [$start, $end])
            ->get([DB::raw('COALESCE(orders.paid_at, orders.created_at) as sold_at')]);

        foreach ($rows as $row) {
            $day = $this->dayKey($row->sold_at);
            if (array_key_exists($day, $values)) {
                $values[$day]++;
            }
        }

        return array_values($values);
    }

    private function partnerGrowthTrendForWindow(array $window): array
    {
        return $this->dailyTrend($window, [
            ['key' => 'new_members', 'label' => 'Members', 'table' => 'customers', 'date' => 'created_at'],
            ['key' => 'new_partners', 'label' => 'Partners', 'table' => 'partners', 'date' => 'created_at'],
            ['key' => 'new_stores', 'label' => 'Stores', 'table' => 'partner_tenants', 'date' => 'created_at'],
        ]);
    }

    /**
     * @return array<string, mixed>
     */
    private function partnerSalesComparisonForWindow(array $window, int $limit = 100): array
    {
        $currentRows = $this->partnerSalesRowsForWindow($window);
        $previousRows = $this->partnerSalesRowsForWindow($window, true);
        $ticketCounts = $this->partnerTicketCountsForWindow($window);
        $previousTicketCounts = $this->partnerTicketCountsForWindow($window, true);
        $ids = array_keys($currentRows);
        $rows = [];

        foreach ($ids as $partnerId) {
            $current = $currentRows[$partnerId] ?? [];
            $previous = $previousRows[$partnerId] ?? [];
            $salesAmount = (int) ($current['value'] ?? 0);
            $previousSalesAmount = (int) ($previous['value'] ?? 0);
            $delta = $this->dashboardDelta($salesAmount, $previousSalesAmount);
            $ticketCount = (int) ($ticketCounts[$partnerId] ?? 0);
            $previousTicketCount = (int) ($previousTicketCounts[$partnerId] ?? 0);
            $ticketDelta = $this->dashboardDelta($ticketCount, $previousTicketCount);

            $rows[] = [
                'id' => (string) $partnerId,
                'code' => (string) ($current['code'] ?? ''),
                'name' => (string) ($current['name'] ?? 'Partner'),
                'status' => (string) ($current['status'] ?? 'active'),
                'value' => $salesAmount,
                'type' => 'money',
                'sales_amount' => $this->money($salesAmount),
                'previous_sales_amount' => $this->money($previousSalesAmount),
                'sales_delta' => $delta['amount'],
                'sales_delta_percent' => $delta['percent'],
                'sales_delta_direction' => $delta['direction'],
                'ticket_count' => $ticketCount,
                'previous_ticket_count' => $previousTicketCount,
                'ticket_delta' => $ticketDelta['amount'],
                'ticket_delta_percent' => $ticketDelta['percent'],
                'ticket_delta_direction' => $ticketDelta['direction'],
                'order_count' => (int) ($current['order_count'] ?? 0),
                'customer_count' => (int) ($current['customer_count'] ?? 0),
            ];
        }

        usort($rows, fn (array $left, array $right): int => ($right['value'] <=> $left['value']) ?: ($right['ticket_count'] <=> $left['ticket_count']));
        $rows = array_slice($rows, 0, $limit);

        return [
            'labels' => array_map(fn (array $row): string => (string) $row['name'], $rows),
            'type' => 'money',
            'rows' => $rows,
        ];
    }

    /**
     * @return array<string, mixed>
     */
    private function partnerNewMembersComparisonForWindow(array $window, int $limit = 100): array
    {
        $currentRows = $this->partnerCountRowsForWindow('customers', 'created_at', $window);
        $previousRows = $this->partnerCountRowsForWindow('customers', 'created_at', $window, true);
        $ids = array_keys($currentRows);
        $rows = [];

        foreach ($ids as $partnerId) {
            $current = $currentRows[$partnerId] ?? [];
            $memberCount = (int) ($current['value'] ?? 0);
            $previousMemberCount = (int) ($previousRows[$partnerId]['value'] ?? 0);
            $delta = $this->dashboardDelta($memberCount, $previousMemberCount);
            $rows[] = [
                'id' => (string) $partnerId,
                'code' => (string) ($current['code'] ?? ''),
                'name' => (string) ($current['name'] ?? 'Partner'),
                'status' => (string) ($current['status'] ?? 'active'),
                'value' => $memberCount,
                'member_count' => $memberCount,
                'previous_member_count' => $previousMemberCount,
                'member_delta' => $delta['amount'],
                'member_delta_percent' => $delta['percent'],
                'member_delta_direction' => $delta['direction'],
            ];
        }

        usort($rows, fn (array $left, array $right): int => ($right['member_count'] <=> $left['member_count']) ?: strcmp((string) $left['name'], (string) $right['name']));
        $rows = array_slice($rows, 0, $limit);

        return [
            'labels' => array_map(fn (array $row): string => (string) $row['name'], $rows),
            'type' => 'number',
            'rows' => $rows,
        ];
    }

    /**
     * @return array<string, mixed>
     */
    private function partnerAffiliateAccountsComparisonForWindow(array $window, int $limit = 100): array
    {
        $newRows = $this->partnerCountRowsForWindow('affiliate_accounts', 'created_at', $window);
        $previousNewRows = $this->partnerCountRowsForWindow('affiliate_accounts', 'created_at', $window, true);
        $ids = array_keys($newRows);
        $rows = [];

        foreach ($ids as $partnerId) {
            $current = $newRows[$partnerId] ?? [];
            $newAccountCount = (int) ($newRows[$partnerId]['value'] ?? 0);
            $previousNewAccountCount = (int) ($previousNewRows[$partnerId]['value'] ?? 0);
            $accountCount = $newAccountCount;
            $previousAccountCount = $previousNewAccountCount;
            $accountDelta = $this->dashboardDelta($accountCount, $previousAccountCount);
            $delta = $this->dashboardDelta($newAccountCount, $previousNewAccountCount);

            $rows[] = [
                'id' => (string) $partnerId,
                'code' => (string) ($current['code'] ?? ''),
                'name' => (string) ($current['name'] ?? 'Partner'),
                'status' => (string) ($current['status'] ?? 'active'),
                'value' => $accountCount,
                'account_count' => $accountCount,
                'previous_account_count' => $previousAccountCount,
                'account_delta' => $accountDelta['amount'],
                'account_delta_percent' => $accountDelta['percent'],
                'account_delta_direction' => $accountDelta['direction'],
                'new_account_count' => $newAccountCount,
                'previous_new_account_count' => $previousNewAccountCount,
                'new_account_delta' => $delta['amount'],
                'new_account_delta_percent' => $delta['percent'],
                'new_account_delta_direction' => $delta['direction'],
            ];
        }

        usort($rows, fn (array $left, array $right): int => ($right['account_count'] <=> $left['account_count']) ?: ($right['new_account_count'] <=> $left['new_account_count']));
        $rows = array_slice($rows, 0, $limit);

        return [
            'labels' => array_map(fn (array $row): string => (string) $row['name'], $rows),
            'type' => 'number',
            'rows' => $rows,
        ];
    }

    /**
     * @return array<string, array<string, mixed>>
     */
    private function partnerSalesRowsForWindow(array $window, bool $previous = false): array
    {
        if (! $this->tableExists('orders') || ! $this->tableExists('partner_tenants') || ! $this->tableExists('partners')) {
            return [];
        }

        $query = $this->ordersForWindow($window, $previous);
        if ($query === null) {
            return [];
        }

        return $query
            ->join('partner_tenants', 'partner_tenants.id', '=', 'orders.tenant_id')
            ->join('partners', 'partners.id', '=', 'partner_tenants.partner_id')
            ->select([
                'partners.id',
                'partners.code',
                'partners.name',
                'partners.status',
                DB::raw('SUM(orders.total_amount) as sales_amount'),
                DB::raw('COUNT(DISTINCT orders.id) as order_count'),
                DB::raw('COUNT(DISTINCT orders.customer_id) as customer_count'),
            ])
            ->groupBy('partners.id', 'partners.code', 'partners.name', 'partners.status')
            ->get()
            ->mapWithKeys(fn (object $row): array => [(string) $row->id => [
                'id' => (string) $row->id,
                'code' => (string) $row->code,
                'name' => (string) $row->name,
                'status' => (string) $row->status,
                'value' => (int) $row->sales_amount,
                'order_count' => (int) $row->order_count,
                'customer_count' => (int) $row->customer_count,
            ]])
            ->all();
    }

    /**
     * @return array<string, int>
     */
    private function partnerTicketCountsForWindow(array $window, bool $previous = false): array
    {
        if (! $this->tableExists('tickets') || ! $this->tableExists('orders') || ! $this->tableExists('partner_tenants')) {
            return [];
        }

        $query = DB::table('tickets')
            ->join('orders', 'orders.id', '=', 'tickets.order_id')
            ->join('partner_tenants', 'partner_tenants.id', '=', 'orders.tenant_id')
            ->where(function ($query): void {
                $query->where('orders.payment_status', 'paid')
                    ->orWhereNotNull('orders.paid_at')
                    ->orWhereIn('orders.status', ['paid', 'completed']);
            });

        $gameId = $previous ? $window['previous_game_id'] : $window['game_id'];
        if ($gameId !== null) {
            $query->where('tickets.game_id', $gameId);
        } else {
            $this->applyTimeWindow($query, $window, 'orders.paid_at', $previous, 'orders.created_at');
        }

        return $query
            ->select(['partner_tenants.partner_id', DB::raw('COUNT(DISTINCT tickets.id) as ticket_count')])
            ->groupBy('partner_tenants.partner_id')
            ->get()
            ->mapWithKeys(fn (object $row): array => [(string) $row->partner_id => (int) $row->ticket_count])
            ->all();
    }

    /**
     * @return array<string, array<string, mixed>>
     */
    private function partnerCountRowsForWindow(string $table, string $dateColumn, array $window, bool $previous = false, bool $applyWindow = true): array
    {
        if (! $this->tableExists($table) || ! $this->tableExists('partner_tenants') || ! $this->tableExists('partners')) {
            return [];
        }

        if ($applyWindow && ! Schema::hasColumn($table, $dateColumn)) {
            return [];
        }

        $query = DB::table($table)
            ->join('partner_tenants', 'partner_tenants.id', '=', $table.'.tenant_id')
            ->join('partners', 'partners.id', '=', 'partner_tenants.partner_id');

        if ($applyWindow) {
            $this->applyTimeWindow($query, $window, $table.'.'.$dateColumn, $previous);
        }

        return $query
            ->select([
                'partners.id',
                'partners.code',
                'partners.name',
                'partners.status',
                DB::raw('COUNT(DISTINCT '.$table.'.id) as row_count'),
            ])
            ->groupBy('partners.id', 'partners.code', 'partners.name', 'partners.status')
            ->get()
            ->mapWithKeys(fn (object $row): array => [(string) $row->id => [
                'id' => (string) $row->id,
                'code' => (string) $row->code,
                'name' => (string) $row->name,
                'status' => (string) $row->status,
                'value' => (int) $row->row_count,
            ]])
            ->all();
    }

    /**
     * @return array<string, array<string, mixed>>
     */
    private function partnerCountRowsUntil(string $table, string $dateColumn, array $window, bool $previous = false): array
    {
        if (
            ! $this->tableExists($table)
            || ! $this->tableExists('partner_tenants')
            || ! $this->tableExists('partners')
            || ! Schema::hasColumn($table, $dateColumn)
        ) {
            return [];
        }

        $end = $previous ? $window['previous_end'] : $window['current_end'];

        return DB::table($table)
            ->join('partner_tenants', 'partner_tenants.id', '=', $table.'.tenant_id')
            ->join('partners', 'partners.id', '=', 'partner_tenants.partner_id')
            ->where($table.'.'.$dateColumn, '<=', $end)
            ->select([
                'partners.id',
                'partners.code',
                'partners.name',
                'partners.status',
                DB::raw('COUNT(DISTINCT '.$table.'.id) as row_count'),
            ])
            ->groupBy('partners.id', 'partners.code', 'partners.name', 'partners.status')
            ->get()
            ->mapWithKeys(fn (object $row): array => [(string) $row->id => [
                'id' => (string) $row->id,
                'code' => (string) $row->code,
                'name' => (string) $row->name,
                'status' => (string) $row->status,
                'value' => (int) $row->row_count,
            ]])
            ->all();
    }

    private function walletFlowTrendForWindow(array $window): array
    {
        return $this->dailyTrend($window, [
            ['key' => 'wallet_inflow', 'label' => 'Inflow', 'type' => 'money', 'table' => 'wallet_ledger', 'amount' => 'amount', 'date' => 'posted_at', 'flow' => 'inflow'],
            ['key' => 'wallet_outflow', 'label' => 'Outflow', 'type' => 'money', 'table' => 'wallet_ledger', 'amount' => 'amount', 'date' => 'posted_at', 'flow' => 'outflow'],
            ['key' => 'topups', 'label' => 'Topups', 'type' => 'money', 'table' => 'topup_requests', 'amount' => 'amount', 'date' => 'created_at'],
        ]);
    }

    private function payoutTrendForWindow(array $window): array
    {
        return $this->dailyTrend($window, [
            ['key' => 'reward_payouts', 'label' => 'Reward payouts', 'type' => 'money', 'table' => 'reward_claims', 'amount' => 'prize_amount', 'date' => 'paid_at'],
            ['key' => 'winning_liability', 'label' => 'Winning liability', 'type' => 'money', 'table' => 'winning_tickets', 'amount' => 'amount', 'date' => 'created_at', 'game_column' => 'game_id'],
            ['key' => 'commissions', 'label' => 'Commissions', 'type' => 'money', 'table' => 'commission_transactions', 'amount' => 'amount', 'date' => 'approved_at'],
        ]);
    }

    private function sessionTrendForWindow(array $window): array
    {
        return $this->dailyTrend($window, [
            ['key' => 'member_sessions', 'label' => 'Member sessions', 'table' => 'customer_auth_sessions', 'date' => 'last_used_at'],
            ['key' => 'guest_sessions', 'label' => 'Guest sessions', 'table' => 'public_visit_sessions', 'date' => 'last_seen_at'],
            ['key' => 'admin_sessions', 'label' => 'Admin sessions', 'table' => 'admin_auth_sessions', 'date' => 'last_used_at'],
        ]);
    }

    private function dailyTrend(array $window, array $seriesSpecs): array
    {
        $start = CarbonImmutable::parse($window['current_start'])->startOfDay();
        $end = CarbonImmutable::parse($window['current_end'])->endOfDay();
        $days = max(1, min(14, $start->diffInDays($end) + 1));
        if ($days === 1 && $window['key'] !== 'today') {
            $days = 7;
            $start = $end->subDays(6)->startOfDay();
        }

        $keys = [];
        for ($index = 0; $index < $days; $index++) {
            $keys[] = $start->addDays($index)->format('Y-m-d');
        }

        $series = [];
        foreach ($seriesSpecs as $spec) {
            $values = array_fill_keys($keys, 0);
            $table = (string) $spec['table'];
            $dateColumn = (string) $spec['date'];
            if (! $this->tableExists($table) || ! Schema::hasColumn($table, $dateColumn)) {
                $series[] = ['key' => $spec['key'], 'label' => $spec['label'], 'type' => $spec['type'] ?? 'number', 'values' => array_values($values)];
                continue;
            }

            $query = DB::table($table);
            if (($spec['paid_orders'] ?? false) === true && $table === 'orders') {
                $query->where(function ($query): void {
                    $query->where('payment_status', 'paid')
                        ->orWhereNotNull('paid_at')
                        ->orWhereIn('status', ['paid', 'completed']);
                });
            }
            if (($spec['positive'] ?? false) === true) {
                $query->where((string) $spec['amount'], '>', 0);
            }
            if (($spec['negative'] ?? false) === true) {
                $query->where((string) $spec['amount'], '<', 0);
            }
            if (($spec['flow'] ?? null) === 'inflow' && Schema::hasColumn($table, 'entry_type')) {
                $query->whereNotIn('entry_type', ['debit', 'hold']);
            } elseif (($spec['flow'] ?? null) === 'outflow' && Schema::hasColumn($table, 'entry_type')) {
                $query->whereIn('entry_type', ['debit', 'hold']);
            }
            $gameColumn = $spec['game_column'] ?? null;
            if (is_string($gameColumn) && $window['game_id'] !== null && Schema::hasColumn($table, $gameColumn)) {
                $query->where($gameColumn, $window['game_id']);
            } else {
                $query->whereBetween($dateColumn, [$start, $end]);
            }

            foreach ($query->get([$dateColumn, $spec['amount'] ?? DB::raw('1 as row_count')]) as $row) {
                $day = $this->dayKey($row->{$dateColumn});
                if (! array_key_exists($day, $values)) {
                    continue;
                }
                $amountColumn = $spec['amount'] ?? null;
                $value = $amountColumn === null ? 1 : (int) $row->{$amountColumn};
                $values[$day] += abs($value);
            }

            $series[] = ['key' => $spec['key'], 'label' => $spec['label'], 'type' => $spec['type'] ?? 'number', 'values' => array_values($values)];
        }

        return [
            'labels' => array_map(fn (string $day): string => CarbonImmutable::parse($day)->format('d M'), $keys),
            'keys' => $keys,
            'series' => $series,
        ];
    }

    /**
     * @return array<int, string>
     */
    private function dashboardDateKeys(array $window, bool $previous = false, ?int $limitDays = null): array
    {
        $start = CarbonImmutable::parse($previous ? $window['previous_start'] : $window['current_start'])->startOfDay();
        $end = CarbonImmutable::parse($previous ? $window['previous_end'] : $window['current_end'])->endOfDay();
        $days = max(1, min(14, $start->diffInDays($end) + 1));
        if ($limitDays !== null) {
            $days = max(1, min($days, $limitDays));
        }
        if ($days === 1 && ($window['key'] ?? '') !== 'today') {
            $days = $limitDays ?? 7;
            $start = $end->subDays($days - 1)->startOfDay();
        }

        $keys = [];
        for ($index = 0; $index < $days; $index++) {
            $keys[] = $start->addDays($index)->format('Y-m-d');
        }

        return $keys;
    }

    /**
     * @param array<int, string> $keys
     * @return array<int, int>
     */
    private function ticketTrendValues(array $window, array $keys, bool $previous): array
    {
        $values = array_fill_keys($keys, 0);

        if (! $this->tableExists('tickets') || ! $this->tableExists('orders')) {
            return array_values($values);
        }

        $query = DB::table('tickets')
            ->join('orders', 'orders.id', '=', 'tickets.order_id')
            ->where(function ($query): void {
                $query->where('orders.payment_status', 'paid')
                    ->orWhereNotNull('orders.paid_at')
                    ->orWhereIn('orders.status', ['paid', 'completed']);
            });

        $gameId = $previous ? $window['previous_game_id'] : $window['game_id'];
        if ($gameId !== null) {
            $query->where('tickets.game_id', $gameId);
        } else {
            $this->applyTimeWindow($query, $window, 'orders.paid_at', $previous, 'orders.created_at');
        }

        foreach ($query->get(['orders.paid_at', 'orders.created_at']) as $row) {
            $day = $this->dayKey($row->paid_at ?? $row->created_at);
            if (array_key_exists($day, $values)) {
                $values[$day]++;
            }
        }

        return array_values($values);
    }

    /**
     * @return array<string, array<int, array<string, mixed>>>
     */
    private function popularLotteryNumbersForWindow(array $window): array
    {
        return [
            'back2' => $this->popularTicketNumberSegment($window, 'back2', '2 ท้าย', 'RIGHT(tickets.full_number, 2)'),
            'back3' => $this->popularTicketNumberSegment($window, 'back3', '3 ท้าย', 'RIGHT(tickets.full_number, 3)'),
            'front3' => $this->popularTicketNumberSegment($window, 'front3', '3 หน้า', 'LEFT(tickets.full_number, 3)'),
        ];
    }

    /**
     * @return array<int, array<string, mixed>>
     */
    private function popularTicketNumberSegment(array $window, string $key, string $label, string $expression): array
    {
        if (! $this->tableExists('tickets') || ! $this->tableExists('orders')) {
            return [];
        }

        $currentRows = $this->popularTicketNumberRows($window, $expression, false);
        $numbers = array_values(array_map(fn (object $row): string => (string) $row->number, $currentRows));
        $previousCounts = $numbers === [] ? [] : $this->popularTicketNumberCounts($window, $expression, true, $numbers);

        return array_map(function (object $row) use ($key, $label, $previousCounts): array {
            $number = (string) $row->number;
            $currentCount = (int) $row->ticket_count;
            $previousCount = (int) ($previousCounts[$number] ?? 0);
            $delta = $this->dashboardDelta($currentCount, $previousCount);

            return [
                'key' => $key,
                'label' => $label,
                'number' => $number,
                'ticket_count' => $currentCount,
                'previous_ticket_count' => $previousCount,
                'ticket_count_delta' => $delta['amount'],
                'ticket_count_delta_percent' => $delta['percent'],
                'ticket_count_delta_direction' => $delta['direction'],
                'sales_amount' => $this->money((int) $row->sales_amount),
                'value' => $currentCount,
            ];
        }, $currentRows);
    }

    /**
     * @return array<int, object>
     */
    private function popularTicketNumberRows(array $window, string $expression, bool $previous): array
    {
        return $this->popularTicketNumberQuery($window, $previous)
            ->select([
                DB::raw($expression.' as number'),
                DB::raw('COUNT(tickets.id) as ticket_count'),
                DB::raw('COALESCE(SUM(orders.total_amount), 0) as sales_amount'),
            ])
            ->groupBy('number')
            ->orderByDesc('ticket_count')
            ->orderBy('number')
            ->limit(10)
            ->get()
            ->all();
    }

    /**
     * @param array<int, string> $numbers
     * @return array<string, int>
     */
    private function popularTicketNumberCounts(array $window, string $expression, bool $previous, array $numbers): array
    {
        return $this->popularTicketNumberQuery($window, $previous)
            ->whereIn(DB::raw($expression), $numbers)
            ->select([
                DB::raw($expression.' as number'),
                DB::raw('COUNT(tickets.id) as ticket_count'),
            ])
            ->groupBy('number')
            ->get()
            ->mapWithKeys(fn (object $row): array => [(string) $row->number => (int) $row->ticket_count])
            ->all();
    }

    private function popularTicketNumberQuery(array $window, bool $previous): \Illuminate\Database\Query\Builder
    {
        $query = DB::table('tickets')
            ->join('orders', 'orders.id', '=', 'tickets.order_id')
            ->where(function ($query): void {
                $query->where('orders.payment_status', 'paid')
                    ->orWhereNotNull('orders.paid_at')
                    ->orWhereIn('orders.status', ['paid', 'completed']);
            });

        $gameId = $previous ? ($window['previous_game_id'] ?? null) : ($window['game_id'] ?? null);
        if ($gameId !== null) {
            $query->where('tickets.game_id', $gameId);
        } else {
            $this->applyTimeWindow($query, $window, 'orders.paid_at', $previous, 'orders.created_at');
        }

        return $query;
    }

    /**
     * @return array<int, array<string, mixed>>
     */
    private function stockSetDistributionForWindow(array $window): array
    {
        $rows = [];
        $game = $this->stockSetDistributionGame($window);

        if ($game !== null && $this->tableExists('stock_supply_profiles')) {
            $profile = DB::table('stock_supply_profiles')
                ->where('game_id', (string) $game->id)
                ->where('status', 'active')
                ->orderByDesc('updated_at')
                ->orderByDesc('created_at')
                ->first();

            if ($profile !== null) {
                $sources = collect();
                if ($this->tableExists('virtual_stock_supply_layers')) {
                    $sources = DB::table('virtual_stock_supply_layers')
                        ->where('profile_id', (string) $profile->id)
                        ->where('game_id', (string) $game->id)
                        ->where('status', 'active')
                        ->orderByDesc('created_at')
                        ->get(['id', 'base_count', 'total_capacity', 'set_distribution_json']);
                }

                if ($sources->isEmpty()) {
                    $sources = collect([(object) [
                        'id' => (string) $profile->id,
                        'base_count' => (int) $profile->base_count,
                        'total_capacity' => (int) $profile->total_capacity,
                        'set_distribution_json' => $profile->set_distribution_json,
                    ]]);
                }

                foreach ($sources as $source) {
                    $baseCount = max(0, (int) ($source->base_count ?? $profile->base_count ?? 0));
                    $distribution = $this->normalizeDashboardSetDistribution($this->decodeDashboardJsonArray($source->set_distribution_json ?? null));
                    $usedBasisPoints = 0;

                    foreach ($distribution as $row) {
                        $basisPoints = min(10000 - $usedBasisPoints, max(0, (int) $row['percent_basis_points']));
                        if ($basisPoints <= 0) {
                            continue;
                        }

                        $setSize = max(1, (int) $row['set_size']);
                        $setCount = (int) floor($baseCount * ($basisPoints / 10000));
                        $this->addDashboardSetDistributionRow($rows, $setSize, $basisPoints, $setCount);
                        $usedBasisPoints += $basisPoints;
                    }

                    $remainingBasisPoints = max(0, 10000 - $usedBasisPoints);
                    if ($remainingBasisPoints > 0) {
                        $setCount = max(0, $baseCount - (int) floor($baseCount * ($usedBasisPoints / 10000)));
                        $this->addDashboardSetDistributionRow($rows, 1, $remainingBasisPoints, $setCount);
                    }
                }
            }
        }

        $currentSoldCounts = $this->soldSetDistributionCountsForWindow($window);
        $previousSoldCounts = $this->soldSetDistributionCountsForWindow($window, true);
        foreach (array_unique([
            ...array_keys($currentSoldCounts),
            ...array_keys($previousSoldCounts),
        ]) as $setSize) {
            $setSize = max(1, (int) $setSize);
            if (! isset($rows[$setSize])) {
                $this->addDashboardSetDistributionRow($rows, $setSize, 0, 0);
            }
        }

        $currentSoldTotal = array_sum(array_map(
            fn (array $row): int => (int) $row['set_count'],
            $currentSoldCounts,
        ));

        usort($rows, function (array $left, array $right) use ($currentSoldCounts): int {
            $leftSold = (int) ($currentSoldCounts[(int) $left['set_size']]['set_count'] ?? 0);
            $rightSold = (int) ($currentSoldCounts[(int) $right['set_size']]['set_count'] ?? 0);

            return ($rightSold <=> $leftSold) ?: ($left['set_size'] <=> $right['set_size']);
        });

        return array_map(function (array $row) use ($currentSoldCounts, $previousSoldCounts, $currentSoldTotal): array {
            $setSize = max(1, (int) $row['set_size']);
            $currentSold = $currentSoldCounts[$setSize] ?? ['set_count' => 0, 'ticket_count' => 0];
            $previousSold = $previousSoldCounts[$setSize] ?? ['set_count' => 0, 'ticket_count' => 0];
            $soldSetCount = (int) $currentSold['set_count'];
            $soldTicketCount = (int) $currentSold['ticket_count'];
            $soldPercent = $currentSoldTotal > 0 ? round(($soldSetCount / $currentSoldTotal) * 100, 2) : 0.0;
            $soldDelta = $this->dashboardDelta((int) $currentSold['set_count'], (int) $previousSold['set_count']);

            return [
                'set_size' => $setSize,
                'label' => 'ชุด '.$setSize.' ใบ',
                'percent' => $soldPercent,
                'percent_basis_points' => (int) round($soldPercent * 100),
                'default_percent' => round($row['percent_basis_points'] / 100, 2),
                'default_percent_basis_points' => $row['percent_basis_points'],
                'default_set_count' => $row['set_count'],
                'default_ticket_capacity' => $row['ticket_capacity'],
                'set_count' => $soldSetCount,
                'ticket_capacity' => $soldTicketCount,
                'sold_set_count' => $soldSetCount,
                'previous_sold_set_count' => (int) $previousSold['set_count'],
                'sold_ticket_count' => $soldTicketCount,
                'previous_sold_ticket_count' => (int) $previousSold['ticket_count'],
                'sold_set_delta' => $soldDelta['amount'],
                'sold_set_delta_percent' => $soldDelta['percent'],
                'sold_set_delta_direction' => $soldDelta['direction'],
                'value' => $soldSetCount,
            ];
        }, array_values($rows));
    }

    private function stockSetDistributionGame(array $window): ?object
    {
        $gameId = $window['game_id'] ?? null;
        if (is_string($gameId) && $gameId !== '') {
            return $this->centralDashboardGameById($gameId);
        }

        return $this->centralDashboardCurrentGameRow();
    }

    /**
     * @return array<int, array{set_count: int, ticket_count: int}>
     */
    private function soldSetDistributionCountsForWindow(array $window, bool $previous = false): array
    {
        if (! $this->tableExists('order_items') || ! $this->tableExists('orders')) {
            return [];
        }

        $query = $this->ordersForWindow($window, $previous);
        if ($query === null) {
            return [];
        }

        $setSizeExpression = $this->orderItemSetSizeExpression();
        $rows = $query
            ->join('order_items', 'order_items.order_id', '=', 'orders.id')
            ->selectRaw($setSizeExpression.' as set_size')
            ->selectRaw('COUNT(order_items.id) as ticket_count')
            ->groupByRaw($setSizeExpression)
            ->get();

        $counts = [];
        foreach ($rows as $row) {
            $setSize = max(1, (int) $row->set_size);
            $ticketCount = max(0, (int) $row->ticket_count);
            $setCount = $ticketCount === 0 ? 0 : max(1, (int) floor($ticketCount / $setSize));
            $counts[$setSize] = [
                'set_count' => $setCount,
                'ticket_count' => $ticketCount,
            ];
        }

        return $counts;
    }

    private function orderItemSetSizeExpression(): string
    {
        if (! Schema::hasColumn('order_items', 'sale_price_rule_snapshot_json')) {
            return '1';
        }

        return match (DB::connection()->getDriverName()) {
            'pgsql' => "CASE WHEN order_items.sale_price_rule_snapshot_json->>'set_size' ~ '^[0-9]+$' THEN GREATEST((order_items.sale_price_rule_snapshot_json->>'set_size')::int, 1) ELSE 1 END",
            'mysql', 'mariadb' => "CASE WHEN JSON_UNQUOTE(JSON_EXTRACT(order_items.sale_price_rule_snapshot_json, '$.set_size')) REGEXP '^[0-9]+$' THEN GREATEST(CAST(JSON_UNQUOTE(JSON_EXTRACT(order_items.sale_price_rule_snapshot_json, '$.set_size')) AS UNSIGNED), 1) ELSE 1 END",
            'sqlite' => "CASE WHEN json_extract(order_items.sale_price_rule_snapshot_json, '$.set_size') IS NULL THEN 1 ELSE MAX(CAST(json_extract(order_items.sale_price_rule_snapshot_json, '$.set_size') AS INTEGER), 1) END",
            default => '1',
        };
    }

    /**
     * @param array<int, array<string, mixed>> $rows
     */
    private function addDashboardSetDistributionRow(array &$rows, int $setSize, int $basisPoints, int $setCount): void
    {
        if (! isset($rows[$setSize])) {
            $rows[$setSize] = [
                'set_size' => $setSize,
                'percent_basis_points' => 0,
                'set_count' => 0,
                'ticket_capacity' => 0,
            ];
        }

        $rows[$setSize]['percent_basis_points'] += $basisPoints;
        $rows[$setSize]['set_count'] += $setCount;
        $rows[$setSize]['ticket_capacity'] += $setCount * $setSize;
    }

    /**
     * @return array<int, array{set_size: int, percent_basis_points: int}>
     */
    private function normalizeDashboardSetDistribution(array $distribution): array
    {
        $rows = [];

        foreach ($distribution as $row) {
            if (! is_array($row)) {
                continue;
            }

            $percent = $row['percent_basis_points'] ?? $row['percent'] ?? 0;
            $basisPoints = is_numeric($percent) && (float) $percent <= 100
                ? (int) round(((float) $percent) * 100)
                : (int) $percent;
            $rows[] = [
                'set_size' => max(1, (int) ($row['set_size'] ?? $row['size'] ?? 1)),
                'percent_basis_points' => max(0, $basisPoints),
            ];
        }

        usort($rows, fn (array $left, array $right): int => $left['set_size'] <=> $right['set_size']);

        return $rows;
    }

    /**
     * @return array<int, mixed>
     */
    private function decodeDashboardJsonArray(mixed $value): array
    {
        if (is_array($value)) {
            return $value;
        }

        if (! is_string($value) || trim($value) === '') {
            return [];
        }

        $decoded = json_decode($value, true);

        return is_array($decoded) ? $decoded : [];
    }

    private function groupedBreakdown(
        string $table,
        string $groupColumn,
        array $window,
        string $amountColumn = '',
        string $dateColumn = 'created_at',
        int $limit = 8,
        ?string $gameColumn = null,
    ): array
    {
        if (! $this->tableExists($table) || ! Schema::hasColumn($table, $groupColumn) || ! Schema::hasColumn($table, $dateColumn)) {
            return [];
        }

        $selectValue = $amountColumn !== '' && Schema::hasColumn($table, $amountColumn)
            ? DB::raw('SUM('.$amountColumn.') as value')
            : DB::raw('COUNT(*) as value');

        $query = DB::table($table)
            ->select([$groupColumn.' as label', $selectValue])
            ->groupBy($groupColumn)
            ->orderByDesc('value')
            ->limit($limit);
        if ($gameColumn !== null && $window['game_id'] !== null && Schema::hasColumn($table, $gameColumn)) {
            $query->where($gameColumn, $window['game_id']);
        } else {
            $this->applyTimeWindow($query, $window, $table.'.'.$dateColumn, fallbackColumn: $dateColumn === 'created_at' ? null : $table.'.created_at');
        }

        return $query->get()
            ->map(fn (object $row): array => [
                'label' => $row->label === null || $row->label === '' ? 'Unknown' : $this->labelize((string) $row->label),
                'value' => (int) $row->value,
                'type' => $amountColumn !== '' ? 'money' : 'number',
            ])
            ->all();
    }

    private function ordersPaymentMethodBreakdown(array $window): array
    {
        return $this->groupedBreakdown('orders', 'payment_method', $window, 'total_amount', 'created_at');
    }

    private function affiliateStatusBreakdown(array $window): array
    {
        return $this->groupedBreakdown('affiliate_attributions', 'status', $window);
    }

    private function topupChannelBreakdown(array $window): array
    {
        return $this->groupedBreakdown('topup_requests', 'channel', $window, 'amount');
    }

    private function paymentProviderBreakdown(array $window): array
    {
        return $this->groupedBreakdown('payments', 'provider', $window, 'amount');
    }

    private function rewardClaimStatusBreakdown(array $window): array
    {
        return $this->groupedBreakdown('reward_claims', 'status', $window, 'prize_amount', 'submitted_at', 8, 'game_id');
    }

    private function rewardPayoutMethodBreakdown(array $window): array
    {
        return $this->groupedBreakdown('reward_claims', 'payout_method', $window, 'prize_amount', 'submitted_at', 8, 'game_id');
    }

    private function winningPrizeTypeBreakdown(array $window): array
    {
        if (! $this->tableExists('winning_tickets')) {
            return [];
        }

        $query = DB::table('winning_tickets')
            ->select([
                'prize_type as label',
                DB::raw('SUM(amount) as value'),
                DB::raw('COUNT(id) as ticket_count'),
            ])
            ->groupBy('prize_type')
            ->orderByDesc('ticket_count')
            ->limit(12);

        if ($window['game_id'] !== null) {
            $query->where('game_id', $window['game_id']);
        } else {
            $this->applyTimeWindow($query, $window, 'winning_tickets.created_at');
        }

        return $query->get()
            ->map(fn (object $row): array => [
                'label' => $row->label === null || $row->label === '' ? 'Unknown' : $this->labelize((string) $row->label),
                'value' => (int) $row->value,
                'type' => 'money',
                'ticket_count' => (int) $row->ticket_count,
            ])
            ->all();
    }

    private function monitorSourceBreakdown(array $window): array
    {
        $query = $this->monitorPublicVisitSessionsQuery($window);

        if ($query !== null) {
            $rows = $query
                ->select(['source as label', DB::raw('COUNT(*) as value')])
                ->groupBy('source')
                ->orderByDesc('value')
                ->limit(8)
                ->get()
                ->map(fn (object $row): array => [
                    'label' => $row->label === null || $row->label === '' ? 'Direct' : $this->labelize((string) $row->label),
                    'value' => (int) $row->value,
                ])
                ->all();

            if ($rows !== []) {
                return $rows;
            }
        }

        return [
            ['label' => 'Members', 'value' => $this->monitorCustomerSessionsCount($window)],
            ['label' => 'Admins', 'value' => $this->monitorAdminSessionsCount($window)],
            ['label' => 'Guests', 'value' => $this->monitorPublicVisitSessionsCount($window, true)],
        ];
    }

    private function topPartnersBySales(array $window, int $limit = 6): array
    {
        if (! $this->tableExists('orders') || ! $this->tableExists('partner_tenants') || ! $this->tableExists('partners')) {
            return [];
        }

        $query = $this->ordersForWindow($window);
        if ($query === null) {
            return [];
        }

        return $query
            ->join('partner_tenants', 'partner_tenants.id', '=', 'orders.tenant_id')
            ->join('partners', 'partners.id', '=', 'partner_tenants.partner_id')
            ->select([
                'partners.id',
                'partners.code',
                'partners.name',
                'partners.status',
                DB::raw('SUM(orders.total_amount) as sales_amount'),
                DB::raw('COUNT(DISTINCT orders.id) as order_count'),
                DB::raw('COUNT(DISTINCT orders.customer_id) as customer_count'),
            ])
            ->groupBy('partners.id', 'partners.code', 'partners.name', 'partners.status')
            ->orderByDesc('sales_amount')
            ->limit($limit)
            ->get()
            ->map(fn (object $row): array => [
                'id' => (string) $row->id,
                'code' => (string) $row->code,
                'name' => (string) $row->name,
                'status' => (string) $row->status,
                'value' => (int) $row->sales_amount,
                'sales_amount' => $this->money((int) $row->sales_amount),
                'order_count' => (int) $row->order_count,
                'customer_count' => (int) $row->customer_count,
            ])
            ->all();
    }

    private function topTenantsBySales(array $window, int $limit = 8): array
    {
        if (! $this->tableExists('orders') || ! $this->tableExists('partner_tenants') || ! $this->tableExists('partners')) {
            return [];
        }

        $query = $this->ordersForWindow($window);
        if ($query === null) {
            return [];
        }

        return $query
            ->join('partner_tenants', 'partner_tenants.id', '=', 'orders.tenant_id')
            ->join('partners', 'partners.id', '=', 'partner_tenants.partner_id')
            ->select([
                'partner_tenants.id',
                'partner_tenants.code',
                'partner_tenants.name',
                'partner_tenants.status',
                'partners.name as partner_name',
                DB::raw('SUM(orders.total_amount) as sales_amount'),
                DB::raw('COUNT(DISTINCT orders.id) as order_count'),
                DB::raw('COUNT(DISTINCT orders.customer_id) as customer_count'),
            ])
            ->groupBy('partner_tenants.id', 'partner_tenants.code', 'partner_tenants.name', 'partner_tenants.status', 'partners.name')
            ->orderByDesc('sales_amount')
            ->limit($limit)
            ->get()
            ->map(fn (object $row): array => [
                'id' => (string) $row->id,
                'code' => (string) $row->code,
                'name' => (string) $row->name,
                'partner_name' => (string) $row->partner_name,
                'status' => (string) $row->status,
                'value' => (int) $row->sales_amount,
                'sales_amount' => $this->money((int) $row->sales_amount),
                'order_count' => (int) $row->order_count,
                'customer_count' => (int) $row->customer_count,
            ])
            ->all();
    }

    private function topTenantsByWalletFlow(array $window, int $limit = 8): array
    {
        if (! $this->tableExists('wallet_ledger') || ! $this->tableExists('partner_tenants') || ! $this->tableExists('partners')) {
            return [];
        }

        $query = DB::table('wallet_ledger')
            ->join('partner_tenants', 'partner_tenants.id', '=', 'wallet_ledger.tenant_id')
            ->join('partners', 'partners.id', '=', 'partner_tenants.partner_id')
            ->select([
                'partner_tenants.id',
                'partner_tenants.code',
                'partner_tenants.name',
                'partners.name as partner_name',
                DB::raw("SUM(CASE WHEN wallet_ledger.entry_type NOT IN ('debit', 'hold') THEN ABS(wallet_ledger.amount) ELSE 0 END) as inflow_amount"),
                DB::raw("SUM(CASE WHEN wallet_ledger.entry_type IN ('debit', 'hold') THEN ABS(wallet_ledger.amount) ELSE 0 END) as outflow_amount"),
                DB::raw('COUNT(wallet_ledger.id) as transaction_count'),
            ])
            ->groupBy('partner_tenants.id', 'partner_tenants.code', 'partner_tenants.name', 'partners.name')
            ->orderByDesc('inflow_amount')
            ->limit($limit);
        $this->applyTimeWindow($query, $window, 'wallet_ledger.posted_at', fallbackColumn: 'wallet_ledger.created_at');

        return $query->get()
            ->map(fn (object $row): array => [
                'id' => (string) $row->id,
                'code' => (string) $row->code,
                'name' => (string) $row->name,
                'partner_name' => (string) $row->partner_name,
                'value' => (int) $row->inflow_amount,
                'inflow_amount' => $this->money((int) $row->inflow_amount),
                'outflow_amount' => $this->money((int) $row->outflow_amount),
                'transaction_count' => (int) $row->transaction_count,
            ])
            ->all();
    }

    private function topPartnersByPayout(array $window, int $limit = 8): array
    {
        if (! $this->tableExists('reward_claims') || ! $this->tableExists('partner_tenants') || ! $this->tableExists('partners')) {
            return [];
        }

        $query = DB::table('reward_claims')
            ->join('partner_tenants', 'partner_tenants.id', '=', 'reward_claims.tenant_id')
            ->join('partners', 'partners.id', '=', 'partner_tenants.partner_id')
            ->select([
                'partners.id',
                'partners.code',
                'partners.name',
                DB::raw('SUM(reward_claims.prize_amount) as payout_amount'),
                DB::raw('COUNT(reward_claims.id) as claim_count'),
                DB::raw("SUM(CASE WHEN reward_claims.status IN ('approved', 'paid') THEN 1 ELSE 0 END) as approved_count"),
                DB::raw("SUM(CASE WHEN reward_claims.status = 'rejected' THEN 1 ELSE 0 END) as rejected_count"),
                DB::raw("SUM(CASE WHEN reward_claims.status NOT IN ('approved', 'paid', 'rejected') THEN 1 ELSE 0 END) as other_status_count"),
            ])
            ->groupBy('partners.id', 'partners.code', 'partners.name')
            ->orderByDesc('payout_amount')
            ->limit($limit);
        if ($window['game_id'] !== null) {
            $query->where('reward_claims.game_id', $window['game_id']);
        } else {
            $this->applyTimeWindow($query, $window, 'reward_claims.paid_at', fallbackColumn: 'reward_claims.created_at');
        }

        return $query->get()
            ->map(fn (object $row): array => [
                'id' => (string) $row->id,
                'code' => (string) $row->code,
                'name' => (string) $row->name,
                'value' => (int) $row->payout_amount,
                'payout_amount' => $this->money((int) $row->payout_amount),
                'claim_count' => (int) $row->claim_count,
                'approved_count' => (int) $row->approved_count,
                'rejected_count' => (int) $row->rejected_count,
                'other_status_count' => (int) $row->other_status_count,
            ])
            ->all();
    }

    private function topPartnersByCommission(array $window, int $limit = 8): array
    {
        if (! $this->tableExists('commission_transactions') || ! $this->tableExists('partner_tenants') || ! $this->tableExists('partners')) {
            return [];
        }

        $query = DB::table('commission_transactions')
            ->join('partner_tenants', 'partner_tenants.id', '=', 'commission_transactions.tenant_id')
            ->join('partners', 'partners.id', '=', 'partner_tenants.partner_id')
            ->select([
                'partners.id',
                'partners.code',
                'partners.name',
                DB::raw('SUM(commission_transactions.amount) as commission_amount'),
                DB::raw('COUNT(commission_transactions.id) as transaction_count'),
                DB::raw("SUM(CASE WHEN commission_transactions.status IN ('approved', 'paid') THEN 1 ELSE 0 END) as approved_count"),
                DB::raw("SUM(CASE WHEN commission_transactions.status = 'rejected' THEN 1 ELSE 0 END) as rejected_count"),
                DB::raw("SUM(CASE WHEN commission_transactions.status NOT IN ('approved', 'paid', 'rejected') THEN 1 ELSE 0 END) as other_status_count"),
            ])
            ->groupBy('partners.id', 'partners.code', 'partners.name')
            ->orderByDesc('commission_amount')
            ->limit($limit);

        $this->applyTimeWindow($query, $window, 'commission_transactions.approved_at', fallbackColumn: 'commission_transactions.created_at');

        return $query->get()
            ->map(fn (object $row): array => [
                'id' => (string) $row->id,
                'code' => (string) $row->code,
                'name' => (string) $row->name,
                'value' => (int) $row->commission_amount,
                'commission_amount' => $this->money((int) $row->commission_amount),
                'transaction_count' => (int) $row->transaction_count,
                'approved_count' => (int) $row->approved_count,
                'rejected_count' => (int) $row->rejected_count,
                'other_status_count' => (int) $row->other_status_count,
            ])
            ->all();
    }

    private function recentOrdersForWindow(array $window): array
    {
        if (! $this->tableExists('orders') || ! $this->tableExists('partner_tenants')) {
            return [];
        }

        $query = ($window['key'] ?? null) === 'previous_draw'
            ? $this->ordersForCurrentDraw()
            : $this->ordersForWindow($window);
        if ($query === null) {
            return [];
        }

        return $query
            ->join('partner_tenants', 'partner_tenants.id', '=', 'orders.tenant_id')
            ->leftJoin('customers', 'customers.id', '=', 'orders.customer_id')
            ->select(['orders.id', 'orders.reference', 'orders.total_amount', 'orders.payment_method', 'orders.payment_status', 'orders.paid_at', 'orders.created_at', 'partner_tenants.name as tenant_name', 'customers.name as customer_name', 'customers.phone as customer_phone'])
            ->orderByRaw('COALESCE(orders.paid_at, orders.created_at) DESC')
            ->limit(10)
            ->get()
            ->map(fn (object $row): array => [
                'id' => (string) $row->id,
                'title' => (string) ($row->reference ?: $row->id),
                'subtitle' => trim((string) ($row->tenant_name.' · '.($row->customer_name ?: $row->customer_phone ?: 'Customer'))),
                'status' => (string) $row->payment_status,
                'amount' => $this->money((int) $row->total_amount),
                'created_at' => $this->isoDate($row->paid_at ?? $row->created_at),
                'meta' => $this->labelize((string) $row->payment_method),
            ])
            ->all();
    }

    private function ordersForCurrentDraw(): ?\Illuminate\Database\Query\Builder
    {
        $query = $this->paidOrdersQuery();
        if ($query === null) {
            return null;
        }

        $currentGame = $this->centralDashboardCurrentGameRow();
        if ($currentGame !== null) {
            $query->where('orders.game_id', (string) $currentGame->id);
        }

        return $query;
    }

    private function recentPartnersForWindow(array $window): array
    {
        if (! $this->tableExists('partners')) {
            return [];
        }

        $query = DB::table('partners')
            ->select(['id', 'code', 'name', 'type', 'status', 'created_at'])
            ->orderByDesc('created_at')
            ->limit(10);
        $this->applyTimeWindow($query, $window, 'partners.created_at');

        $rows = $query->get()
            ->map(fn (object $row): array => [
                'id' => (string) $row->id,
                'title' => (string) $row->name,
                'subtitle' => (string) $row->code,
                'status' => (string) $row->status,
                'created_at' => $this->isoDate($row->created_at),
                'meta' => $this->labelize((string) $row->type),
            ])
            ->all();

        if ($rows !== []) {
            return $rows;
        }

        return array_map(fn (array $row): array => [
            'id' => (string) ($row['id'] ?? ''),
            'title' => (string) ($row['name'] ?? 'Partner'),
            'subtitle' => trim((string) (($row['code'] ?? '').' · '.number_format((int) ($row['order_count'] ?? 0)).' paid orders')),
            'status' => (string) ($row['status'] ?? 'active'),
            'amount' => $row['sales_amount'] ?? $this->money(0),
            'created_at' => $this->isoDate($window['current_end'] ?? now()),
            'meta' => 'Top partner by sales',
        ], $this->topPartnersBySales($window, 10));
    }

    private function recentWalletLedgerForWindow(array $window): array
    {
        if (! $this->tableExists('wallet_ledger') || ! $this->tableExists('partner_tenants')) {
            return [];
        }

        $query = DB::table('wallet_ledger')
            ->join('partner_tenants', 'partner_tenants.id', '=', 'wallet_ledger.tenant_id')
            ->select(['wallet_ledger.id', 'wallet_ledger.entry_type', 'wallet_ledger.status', 'wallet_ledger.amount', 'wallet_ledger.balance_after', 'wallet_ledger.posted_at', 'wallet_ledger.created_at', 'partner_tenants.name as tenant_name'])
            ->orderByRaw('COALESCE(wallet_ledger.posted_at, wallet_ledger.created_at) DESC')
            ->limit(10);
        $this->applyTimeWindow($query, $window, 'wallet_ledger.posted_at', fallbackColumn: 'wallet_ledger.created_at');

        return $query->get()
            ->map(fn (object $row): array => [
                'id' => (string) $row->id,
                'title' => $this->labelize((string) $row->entry_type),
                'subtitle' => (string) $row->tenant_name,
                'status' => (string) $row->status,
                'amount' => $this->money((int) $row->amount),
                'balance_after' => $this->money((int) $row->balance_after),
                'created_at' => $this->isoDate($row->posted_at ?? $row->created_at),
            ])
            ->all();
    }

    private function recentRewardClaimsForWindow(array $window): array
    {
        if (! $this->tableExists('reward_claims') || ! $this->tableExists('partner_tenants')) {
            return [];
        }

        $query = DB::table('reward_claims')
            ->join('partner_tenants', 'partner_tenants.id', '=', 'reward_claims.tenant_id')
            ->select(['reward_claims.id', 'reward_claims.status', 'reward_claims.payout_method', 'reward_claims.prize_amount', 'reward_claims.submitted_at', 'reward_claims.paid_at', 'reward_claims.created_at', 'partner_tenants.name as tenant_name'])
            ->orderByRaw('COALESCE(reward_claims.paid_at, reward_claims.submitted_at, reward_claims.created_at) DESC')
            ->limit(10);
        if ($window['game_id'] !== null) {
            $query->where('reward_claims.game_id', $window['game_id']);
        } else {
            $this->applyTimeWindow($query, $window, 'reward_claims.submitted_at', fallbackColumn: 'reward_claims.created_at');
        }

        return $query->get()
            ->map(fn (object $row): array => [
                'id' => (string) $row->id,
                'title' => 'Reward claim',
                'subtitle' => (string) $row->tenant_name,
                'status' => (string) $row->status,
                'amount' => $this->money((int) $row->prize_amount),
                'created_at' => $this->isoDate($row->paid_at ?? $row->submitted_at ?? $row->created_at),
                'meta' => $this->labelize((string) $row->payout_method),
            ])
            ->all();
    }

    private function activePublicVisitSessionsCount(?bool $guestOnly = null): int
    {
        $query = $this->activePublicVisitSessionsQuery($guestOnly);

        return $query === null ? 0 : (int) $query->count();
    }

    private function monitorPublicVisitSessionsCount(array $window, ?bool $guestOnly = null, bool $previous = false): int
    {
        $query = $this->monitorPublicVisitSessionsQuery($window, $guestOnly, $previous);

        return $query === null ? 0 : (int) $query->count();
    }

    private function monitorPublicVisitSessionsQuery(array $window, ?bool $guestOnly = null, bool $previous = false): ?\Illuminate\Database\Query\Builder
    {
        if (! $this->tableExists('public_visit_sessions')) {
            return null;
        }

        $query = DB::table('public_visit_sessions');
        $this->applyTimeWindow($query, $window, 'public_visit_sessions.last_seen_at', $previous);

        if ($guestOnly === true) {
            $query->whereNull('public_visit_sessions.customer_id');
        } elseif ($guestOnly === false) {
            $query->whereNotNull('public_visit_sessions.customer_id');
        }

        return $query;
    }

    private function monitorCustomerSessionsCount(array $window, bool $previous = false): int
    {
        $query = $this->monitorCustomerSessionsQuery($window, $previous);

        return $query === null ? 0 : (int) $query->count();
    }

    private function monitorCustomerSessionsQuery(array $window, bool $previous = false): ?\Illuminate\Database\Query\Builder
    {
        if (! $this->tableExists('customer_auth_sessions')) {
            return null;
        }

        $query = DB::table('customer_auth_sessions')
            ->whereNull('customer_auth_sessions.revoked_at');
        $this->applyTimeWindow($query, $window, 'customer_auth_sessions.last_used_at', $previous, 'customer_auth_sessions.created_at');

        return $query;
    }

    private function monitorAdminSessionsCount(array $window, bool $previous = false): int
    {
        $query = $this->monitorAdminSessionsQuery($window, $previous);

        return $query === null ? 0 : (int) $query->count();
    }

    private function monitorAdminSessionsQuery(array $window, bool $previous = false): ?\Illuminate\Database\Query\Builder
    {
        if (! $this->tableExists('admin_auth_sessions')) {
            return null;
        }

        $query = DB::table('admin_auth_sessions')
            ->whereNull('admin_auth_sessions.revoked_at');
        $this->applyTimeWindow($query, $window, 'admin_auth_sessions.last_used_at', $previous, 'admin_auth_sessions.created_at');

        return $query;
    }

    private function monitorOwnerPartnerSessionsCount(array $window, bool $previous = false): int
    {
        if (! $this->tableExists('admin_user_roles') || ! $this->tableExists('roles')) {
            return 0;
        }

        $query = $this->monitorAdminSessionsQuery($window, $previous);
        if ($query === null) {
            return 0;
        }

        return (int) $query
            ->join('admin_user_roles', 'admin_user_roles.admin_user_id', '=', 'admin_auth_sessions.admin_user_id')
            ->join('roles', 'roles.id', '=', 'admin_user_roles.role_id')
            ->where('roles.scope_type', 'tenant')
            ->whereIn('roles.code', ['owner', 'owner_partner'])
            ->distinct()
            ->count('admin_auth_sessions.id');
    }

    private function monitorTenantsCount(array $window, bool $previous = false): int
    {
        $tenantIds = [];

        $customerQuery = $this->monitorCustomerSessionsQuery($window, $previous);
        if ($customerQuery !== null) {
            $tenantIds = array_merge($tenantIds, $customerQuery
                ->whereNotNull('tenant_id')
                ->distinct()
                ->pluck('tenant_id')
                ->map(fn (mixed $tenantId): string => (string) $tenantId)
                ->all());
        }

        $publicQuery = $this->monitorPublicVisitSessionsQuery($window, true, $previous);
        if ($publicQuery !== null) {
            $tenantIds = array_merge($tenantIds, $publicQuery
                ->whereNotNull('tenant_id')
                ->distinct()
                ->pluck('tenant_id')
                ->map(fn (mixed $tenantId): string => (string) $tenantId)
                ->all());
        }

        return count(array_unique($tenantIds));
    }

    private function monitorTenantsBreakdown(array $window, int $limit = 8): array
    {
        if (! $this->tableExists('partner_tenants') || ! $this->tableExists('partners')) {
            return [];
        }

        $rows = [];
        $customerQuery = $this->monitorCustomerSessionsQuery($window);
        if ($customerQuery !== null) {
            foreach ($customerQuery
                ->join('partner_tenants', 'partner_tenants.id', '=', 'customer_auth_sessions.tenant_id')
                ->join('partners', 'partners.id', '=', 'partner_tenants.partner_id')
                ->select(['partner_tenants.id', 'partner_tenants.code', 'partner_tenants.name', 'partners.name as partner_name', DB::raw('COUNT(customer_auth_sessions.id) as active_sessions')])
                ->groupBy('partner_tenants.id', 'partner_tenants.code', 'partner_tenants.name', 'partners.name')
                ->get() as $row) {
                $rows[(string) $row->id] = [
                    'id' => (string) $row->id,
                    'code' => (string) $row->code,
                    'name' => (string) $row->name,
                    'partner_name' => (string) $row->partner_name,
                    'value' => (int) $row->active_sessions,
                    'member_sessions' => (int) $row->active_sessions,
                    'guest_sessions' => 0,
                ];
            }
        }

        $guestQuery = $this->monitorPublicVisitSessionsQuery($window, true);
        if ($guestQuery !== null) {
            foreach ($guestQuery
                ->join('partner_tenants', 'partner_tenants.id', '=', 'public_visit_sessions.tenant_id')
                ->join('partners', 'partners.id', '=', 'partner_tenants.partner_id')
                ->select(['partner_tenants.id', 'partner_tenants.code', 'partner_tenants.name', 'partners.name as partner_name', DB::raw('COUNT(public_visit_sessions.id) as active_sessions')])
                ->groupBy('partner_tenants.id', 'partner_tenants.code', 'partner_tenants.name', 'partners.name')
                ->get() as $row) {
                $tenantId = (string) $row->id;
                $rows[$tenantId] ??= [
                    'id' => $tenantId,
                    'code' => (string) $row->code,
                    'name' => (string) $row->name,
                    'partner_name' => (string) $row->partner_name,
                    'value' => 0,
                    'member_sessions' => 0,
                    'guest_sessions' => 0,
                ];
                $rows[$tenantId]['value'] += (int) $row->active_sessions;
                $rows[$tenantId]['guest_sessions'] += (int) $row->active_sessions;
            }
        }

        usort($rows, fn (array $left, array $right): int => $right['value'] <=> $left['value']);

        return array_slice($rows, 0, $limit);
    }

    private function monitorCustomerSessions(array $window): array
    {
        $query = $this->monitorCustomerSessionsQuery($window);
        if ($query === null || ! $this->tableExists('customers') || ! $this->tableExists('partner_tenants')) {
            return [];
        }

        return $query
            ->join('customers', 'customers.id', '=', 'customer_auth_sessions.customer_id')
            ->join('partner_tenants', 'partner_tenants.id', '=', 'customer_auth_sessions.tenant_id')
            ->select(['customer_auth_sessions.id', 'customer_auth_sessions.last_used_at', 'customer_auth_sessions.created_at', 'customers.name', 'customers.phone', 'partner_tenants.name as tenant_name'])
            ->orderByRaw('COALESCE(customer_auth_sessions.last_used_at, customer_auth_sessions.created_at) DESC')
            ->limit(10)
            ->get()
            ->map(fn (object $row): array => [
                'id' => (string) $row->id,
                'title' => (string) ($row->name ?: $row->phone ?: 'Customer'),
                'subtitle' => (string) $row->tenant_name,
                'status' => 'member',
                'created_at' => $this->isoDate($row->last_used_at ?? $row->created_at),
            ])
            ->all();
    }

    private function monitorPublicVisitSessions(array $window): array
    {
        $query = $this->monitorPublicVisitSessionsQuery($window);
        if ($query === null || ! $this->tableExists('partner_tenants')) {
            return [];
        }

        return $query
            ->join('partner_tenants', 'partner_tenants.id', '=', 'public_visit_sessions.tenant_id')
            ->leftJoin('customers', 'customers.id', '=', 'public_visit_sessions.customer_id')
            ->select([
                'public_visit_sessions.id',
                'public_visit_sessions.customer_id',
                'public_visit_sessions.source',
                'public_visit_sessions.channel',
                'public_visit_sessions.path',
                'public_visit_sessions.ip_address',
                'public_visit_sessions.last_seen_at',
                'partner_tenants.name as tenant_name',
                'customers.name as customer_name',
                'customers.phone as customer_phone',
            ])
            ->orderByDesc('public_visit_sessions.last_seen_at')
            ->limit(12)
            ->get()
            ->map(fn (object $row): array => [
                'id' => (string) $row->id,
                'title' => $row->customer_id === null
                    ? $this->labelize((string) $row->source).' visitor'
                    : (string) ($row->customer_name ?: $row->customer_phone ?: 'Member'),
                'subtitle' => trim((string) $row->tenant_name.' - '.($row->ip_address ?: 'No IP')),
                'status' => $row->customer_id === null ? 'guest' : 'member',
                'created_at' => $this->isoDate($row->last_seen_at),
                'meta' => (string) ($row->path ?: ($row->channel ?: $row->source)),
            ])
            ->all();
    }

    private function monitorAdminSessions(array $window): array
    {
        $query = $this->monitorAdminSessionsQuery($window);
        if ($query === null || ! $this->tableExists('admin_users')) {
            return [];
        }

        return $query
            ->join('admin_users', 'admin_users.id', '=', 'admin_auth_sessions.admin_user_id')
            ->leftJoin('partner_tenants', 'partner_tenants.id', '=', 'admin_auth_sessions.tenant_id')
            ->select(['admin_auth_sessions.id', 'admin_auth_sessions.scope_type', 'admin_auth_sessions.tenant_id', 'admin_auth_sessions.last_used_at', 'admin_auth_sessions.created_at', 'admin_users.name', 'admin_users.email', 'partner_tenants.name as tenant_name'])
            ->orderByRaw('COALESCE(admin_auth_sessions.last_used_at, admin_auth_sessions.created_at) DESC')
            ->limit(12)
            ->get()
            ->map(fn (object $row): array => [
                'id' => (string) $row->id,
                'title' => (string) ($row->name ?: $row->email),
                'subtitle' => trim((string) ($row->scope_type === 'tenant' ? ($row->tenant_name ?: $row->tenant_id) : 'Central')),
                'status' => 'admin',
                'created_at' => $this->isoDate($row->last_used_at ?? $row->created_at),
                'meta' => $this->labelize((string) $row->scope_type),
            ])
            ->all();
    }

    private function activePublicVisitSessionsQuery(?bool $guestOnly = null): ?\Illuminate\Database\Query\Builder
    {
        if (! $this->tableExists('public_visit_sessions')) {
            return null;
        }

        $query = DB::table('public_visit_sessions')
            ->where('public_visit_sessions.expires_at', '>=', now())
            ->where('public_visit_sessions.last_seen_at', '>=', now()->subMinutes(15));

        if ($guestOnly === true) {
            $query->whereNull('public_visit_sessions.customer_id');
        } elseif ($guestOnly === false) {
            $query->whereNotNull('public_visit_sessions.customer_id');
        }

        return $query;
    }

    /**
     * @return array<int, string>
     */
    private function activePublicTenantIds(): array
    {
        $query = $this->activePublicVisitSessionsQuery(true);

        if ($query === null) {
            return [];
        }

        return $query->distinct()
            ->pluck('tenant_id')
            ->map(fn (mixed $tenantId): string => (string) $tenantId)
            ->all();
    }

    private function activePublicTenantIdsCount(): int
    {
        return count(array_unique($this->activePublicTenantIds()));
    }

    private function activeCustomerSessionsCount(): int
    {
        if (! $this->tableExists('customer_auth_sessions')) {
            return 0;
        }

        return (int) $this->activeCustomerSessionsQuery()->count();
    }

    private function activeAdminSessionsCount(): int
    {
        if (! $this->tableExists('admin_auth_sessions')) {
            return 0;
        }

        return (int) $this->activeAdminSessionsQuery()->count();
    }

    private function activeOwnerPartnerSessionsCount(): int
    {
        if (! $this->tableExists('admin_auth_sessions') || ! $this->tableExists('admin_user_roles') || ! $this->tableExists('roles')) {
            return 0;
        }

        return (int) $this->activeAdminSessionsQuery()
            ->join('admin_user_roles', 'admin_user_roles.admin_user_id', '=', 'admin_auth_sessions.admin_user_id')
            ->join('roles', 'roles.id', '=', 'admin_user_roles.role_id')
            ->where('roles.scope_type', 'tenant')
            ->whereIn('roles.code', ['owner', 'owner_partner'])
            ->distinct()
            ->count('admin_auth_sessions.id');
    }

    private function activeCustomerTenantsCount(): int
    {
        $tenantIds = [];

        if (! $this->tableExists('customer_auth_sessions')) {
            return $this->activePublicTenantIdsCount();
        }

        $tenantIds = $this->activeCustomerSessionsQuery()
            ->distinct()
            ->pluck('tenant_id')
            ->map(fn (mixed $tenantId): string => (string) $tenantId)
            ->all();

        return count(array_unique(array_merge($tenantIds, $this->activePublicTenantIds())));
    }

    private function activeCustomerSessionsQuery(): \Illuminate\Database\Query\Builder
    {
        return DB::table('customer_auth_sessions')
            ->whereNull('customer_auth_sessions.revoked_at')
            ->where('customer_auth_sessions.access_expires_at', '>=', now())
            ->where(function ($query): void {
                $query->where('customer_auth_sessions.last_used_at', '>=', now()->subMinutes(15))
                    ->orWhere('customer_auth_sessions.created_at', '>=', now()->subMinutes(15));
            });
    }

    private function activeAdminSessionsQuery(): \Illuminate\Database\Query\Builder
    {
        return DB::table('admin_auth_sessions')
            ->whereNull('admin_auth_sessions.revoked_at')
            ->where('admin_auth_sessions.access_expires_at', '>=', now())
            ->where(function ($query): void {
                $query->where('admin_auth_sessions.last_used_at', '>=', now()->subMinutes(15))
                    ->orWhere('admin_auth_sessions.created_at', '>=', now()->subMinutes(15));
            });
    }

    private function activeTenantsBreakdown(int $limit = 8): array
    {
        if (! $this->tableExists('partner_tenants') || ! $this->tableExists('partners')) {
            return [];
        }

        $rows = [];

        if ($this->tableExists('customer_auth_sessions')) {
            foreach ($this->activeCustomerSessionsQuery()
                ->join('partner_tenants', 'partner_tenants.id', '=', 'customer_auth_sessions.tenant_id')
                ->join('partners', 'partners.id', '=', 'partner_tenants.partner_id')
                ->select(['partner_tenants.id', 'partner_tenants.code', 'partner_tenants.name', 'partners.name as partner_name', DB::raw('COUNT(customer_auth_sessions.id) as active_sessions')])
                ->groupBy('partner_tenants.id', 'partner_tenants.code', 'partner_tenants.name', 'partners.name')
                ->get() as $row) {
                $rows[(string) $row->id] = [
                    'id' => (string) $row->id,
                    'code' => (string) $row->code,
                    'name' => (string) $row->name,
                    'partner_name' => (string) $row->partner_name,
                    'value' => (int) $row->active_sessions,
                    'member_sessions' => (int) $row->active_sessions,
                    'guest_sessions' => 0,
                ];
            }
        }

        $guestQuery = $this->activePublicVisitSessionsQuery(true);
        if ($guestQuery !== null) {
            foreach ($guestQuery
                ->join('partner_tenants', 'partner_tenants.id', '=', 'public_visit_sessions.tenant_id')
                ->join('partners', 'partners.id', '=', 'partner_tenants.partner_id')
                ->select(['partner_tenants.id', 'partner_tenants.code', 'partner_tenants.name', 'partners.name as partner_name', DB::raw('COUNT(public_visit_sessions.id) as active_sessions')])
                ->groupBy('partner_tenants.id', 'partner_tenants.code', 'partner_tenants.name', 'partners.name')
                ->get() as $row) {
                $tenantId = (string) $row->id;
                $rows[$tenantId] ??= [
                    'id' => $tenantId,
                    'code' => (string) $row->code,
                    'name' => (string) $row->name,
                    'partner_name' => (string) $row->partner_name,
                    'value' => 0,
                    'member_sessions' => 0,
                    'guest_sessions' => 0,
                ];
                $rows[$tenantId]['value'] += (int) $row->active_sessions;
                $rows[$tenantId]['guest_sessions'] += (int) $row->active_sessions;
            }
        }

        usort($rows, fn (array $left, array $right): int => $right['value'] <=> $left['value']);

        return array_slice($rows, 0, $limit);
    }

    private function activeCustomerSessions(): array
    {
        if (! $this->tableExists('customer_auth_sessions') || ! $this->tableExists('customers')) {
            return [];
        }

        return $this->activeCustomerSessionsQuery()
            ->join('customers', 'customers.id', '=', 'customer_auth_sessions.customer_id')
            ->join('partner_tenants', 'partner_tenants.id', '=', 'customer_auth_sessions.tenant_id')
            ->select(['customer_auth_sessions.id', 'customer_auth_sessions.last_used_at', 'customer_auth_sessions.created_at', 'customers.name', 'customers.phone', 'partner_tenants.name as tenant_name'])
            ->orderByRaw('COALESCE(customer_auth_sessions.last_used_at, customer_auth_sessions.created_at) DESC')
            ->limit(10)
            ->get()
            ->map(fn (object $row): array => [
                'id' => (string) $row->id,
                'title' => (string) ($row->name ?: $row->phone ?: 'Customer'),
                'subtitle' => (string) $row->tenant_name,
                'status' => 'online',
                'created_at' => $this->isoDate($row->last_used_at ?? $row->created_at),
            ])
            ->all();
    }

    private function activePublicVisitSessions(): array
    {
        $query = $this->activePublicVisitSessionsQuery();

        if ($query === null || ! $this->tableExists('partner_tenants')) {
            return [];
        }

        return $query
            ->join('partner_tenants', 'partner_tenants.id', '=', 'public_visit_sessions.tenant_id')
            ->leftJoin('customers', 'customers.id', '=', 'public_visit_sessions.customer_id')
            ->select([
                'public_visit_sessions.id',
                'public_visit_sessions.customer_id',
                'public_visit_sessions.source',
                'public_visit_sessions.channel',
                'public_visit_sessions.path',
                'public_visit_sessions.ip_address',
                'public_visit_sessions.last_seen_at',
                'partner_tenants.name as tenant_name',
                'customers.name as customer_name',
                'customers.phone as customer_phone',
            ])
            ->orderByDesc('public_visit_sessions.last_seen_at')
            ->limit(12)
            ->get()
            ->map(fn (object $row): array => [
                'id' => (string) $row->id,
                'title' => $row->customer_id === null
                    ? $this->labelize((string) $row->source).' visitor'
                    : (string) ($row->customer_name ?: $row->customer_phone ?: 'Member'),
                'subtitle' => trim((string) $row->tenant_name.' - '.($row->ip_address ?: 'No IP')),
                'status' => $row->customer_id === null ? 'guest' : 'member',
                'created_at' => $this->isoDate($row->last_seen_at),
                'meta' => (string) ($row->path ?: ($row->channel ?: $row->source)),
            ])
            ->all();
    }

    private function activeAdminSessions(): array
    {
        if (! $this->tableExists('admin_auth_sessions') || ! $this->tableExists('admin_users')) {
            return [];
        }

        return $this->activeAdminSessionsQuery()
            ->join('admin_users', 'admin_users.id', '=', 'admin_auth_sessions.admin_user_id')
            ->leftJoin('partner_tenants', 'partner_tenants.id', '=', 'admin_auth_sessions.tenant_id')
            ->select(['admin_auth_sessions.id', 'admin_auth_sessions.scope_type', 'admin_auth_sessions.tenant_id', 'admin_auth_sessions.last_used_at', 'admin_auth_sessions.created_at', 'admin_users.name', 'admin_users.email', 'partner_tenants.name as tenant_name'])
            ->orderByRaw('COALESCE(admin_auth_sessions.last_used_at, admin_auth_sessions.created_at) DESC')
            ->limit(12)
            ->get()
            ->map(fn (object $row): array => [
                'id' => (string) $row->id,
                'title' => (string) ($row->name ?: $row->email),
                'subtitle' => trim((string) ($row->scope_type === 'tenant' ? ($row->tenant_name ?: $row->tenant_id) : 'Central')),
                'status' => 'online',
                'created_at' => $this->isoDate($row->last_used_at ?? $row->created_at),
                'meta' => $this->labelize((string) $row->scope_type),
            ])
            ->all();
    }

    private function recentVisitorIpsForWindow(array $window): array
    {
        if (! $this->tableExists('public_visit_sessions')) {
            return $this->recentAuditIpsForWindow($window);
        }

        $query = DB::table('public_visit_sessions')
            ->select(['ip_address as label', DB::raw('COUNT(*) as value'), DB::raw('MAX(last_seen_at) as last_seen_at')])
            ->whereNotNull('ip_address')
            ->groupBy('ip_address')
            ->orderByDesc('value')
            ->limit(10);
        $this->applyTimeWindow($query, $window, 'public_visit_sessions.last_seen_at');

        $rows = $query->get()
            ->map(fn (object $row): array => [
                'label' => (string) $row->label,
                'value' => (int) $row->value,
                'last_seen_at' => $this->isoDate($row->last_seen_at),
            ])
            ->all();

        return $rows === [] ? $this->recentAuditIpsForWindow($window) : $rows;
    }

    private function recentAuditIpsForWindow(array $window): array
    {
        if (! $this->tableExists('audit_logs')) {
            return [];
        }

        $query = DB::table('audit_logs')
            ->select(['ip_address as label', DB::raw('COUNT(*) as value'), DB::raw('MAX(created_at) as last_seen_at')])
            ->whereNotNull('ip_address')
            ->groupBy('ip_address')
            ->orderByDesc('value')
            ->limit(10);
        $this->applyTimeWindow($query, $window, 'audit_logs.created_at');

        return $query->get()
            ->map(fn (object $row): array => [
                'label' => (string) $row->label,
                'value' => (int) $row->value,
                'last_seen_at' => $this->isoDate($row->last_seen_at),
            ])
            ->all();
    }

    /**
     * @return array<string, mixed>
     */
    private function tenantDashboardSummary(?string $tenantId, string $period): array
    {
        $window = $this->tenantDashboardPeriod($period);
        $sales = $this->tenantOrdersSumForWindow($tenantId, $window, 'total_amount');
        $previousSales = $this->tenantOrdersSumForWindow($tenantId, $window, 'total_amount', true);
        $orders = $this->tenantOrdersCountForWindow($tenantId, $window);
        $previousOrders = $this->tenantOrdersCountForWindow($tenantId, $window, true);
        $tickets = $this->tenantTicketsCountForWindow($tenantId, $window);
        $previousTickets = $this->tenantTicketsCountForWindow($tenantId, $window, true);
        $walletInflow = $this->tenantWalletLedgerFlowAmount($tenantId, $window, 'inflow');
        $previousWalletInflow = $this->tenantWalletLedgerFlowAmount($tenantId, $window, 'inflow', true);
        $walletOutflow = $this->tenantWalletLedgerFlowAmount($tenantId, $window, 'outflow');
        $previousWalletOutflow = $this->tenantWalletLedgerFlowAmount($tenantId, $window, 'outflow', true);
        $rewardPayouts = $this->tenantSumForWindow($tenantId, 'reward_claims', 'prize_amount', $window, column: 'paid_at', gameColumn: 'game_id');
        $previousRewardPayouts = $this->tenantSumForWindow($tenantId, 'reward_claims', 'prize_amount', $window, true, column: 'paid_at', gameColumn: 'game_id');
        $paidCustomers = $this->tenantOrdersCustomerCountForWindow($tenantId, $window);
        $previousPaidCustomers = $this->tenantOrdersCustomerCountForWindow($tenantId, $window, true);
        $stockAvailable = $this->tenantStockCount($tenantId, $window, ['available']);
        $previousStockAvailable = $this->tenantStockCount($tenantId, $window, ['available'], true);

        return [
            'scope' => 'tenant',
            'tenant_id' => $tenantId,
            'generated_at' => now()->toISOString(),
            'filter' => [
                'period' => $window['key'],
                'label' => $window['label'],
                'current' => [
                    'label' => $window['current_label'],
                    'start_at' => $this->isoDate($window['current_start']),
                    'end_at' => $this->isoDate($window['current_end']),
                    'game_id' => $window['game_id'],
                ],
                'previous' => [
                    'label' => $window['previous_label'],
                    'start_at' => $this->isoDate($window['previous_start']),
                    'end_at' => $this->isoDate($window['previous_end']),
                    'game_id' => $window['previous_game_id'],
                ],
                'options' => $this->tenantDashboardPeriodOptions(),
            ],
            'hero' => [
                'label' => 'Tenant paid sales',
                'value' => $this->money($sales),
                'previous' => $this->money($previousSales),
                'delta' => $this->dashboardDelta($sales, $previousSales),
                'caption' => 'Paid lottery sales, tickets, wallet movement, and reward payouts for this tenant.',
            ],
            'metrics' => [
                $this->dashboardMetric('sales_amount', 'Paid sales', 'money', $sales, $previousSales, 'ri-money-dollar-circle-line', 'primary'),
                $this->dashboardMetric('tickets_sold', 'Tickets sold', 'number', $tickets, $previousTickets, 'ri-ticket-2-line', 'success'),
                $this->dashboardMetric('paid_orders', 'Paid orders', 'number', $orders, $previousOrders, 'ri-shopping-bag-3-line', 'info'),
                $this->dashboardMetric('average_order', 'Average order', 'money', $orders > 0 ? (int) round($sales / $orders) : 0, $previousOrders > 0 ? (int) round($previousSales / $previousOrders) : 0, 'ri-bar-chart-grouped-line', 'warning'),
                $this->dashboardMetric('paid_customers', 'Paid customers', 'number', $paidCustomers, $previousPaidCustomers, 'ri-user-heart-line', 'secondary'),
                $this->dashboardMetric('wallet_net', 'Wallet net', 'money', $walletInflow - $walletOutflow, $previousWalletInflow - $previousWalletOutflow, 'ri-wallet-3-line', 'primary'),
                $this->dashboardMetric('reward_payouts', 'Reward payouts', 'money', $rewardPayouts, $previousRewardPayouts, 'ri-trophy-line', 'pink'),
                $this->dashboardMetric('stock_available', 'Available stock', 'number', $stockAvailable, $previousStockAvailable, 'ri-stack-line', 'success'),
            ],
            'kpis' => $this->tenantDashboardKpis($tenantId, $window),
            'charts' => [
                'primary_trend' => $this->tenantSalesTrendForWindow($tenantId, $window),
                'sales_trend' => $this->tenantSalesTrendForWindow($tenantId, $window),
                'wallet_flow' => $this->tenantWalletFlowTrendForWindow($tenantId, $window),
                'secondary_breakdown' => $this->tenantGroupedBreakdown($tenantId, 'orders', 'payment_method', $window, 'total_amount', 'paid_at', 8, 'game_id', paidOrders: true),
                'payment_methods' => $this->tenantGroupedBreakdown($tenantId, 'orders', 'payment_method', $window, 'total_amount', 'paid_at', 8, 'game_id', paidOrders: true),
                'orders_by_status' => $this->tenantGroupedBreakdown($tenantId, 'orders', 'status', $window, dateColumn: 'created_at', gameColumn: 'game_id'),
                'stock_by_status' => $this->tenantStockStatusBreakdown($tenantId, $window),
                'reward_claims_by_status' => $this->tenantGroupedBreakdown($tenantId, 'reward_claims', 'status', $window, dateColumn: 'submitted_at', gameColumn: 'game_id'),
                'reward_payout_methods' => $this->tenantGroupedBreakdown($tenantId, 'reward_claims', 'payout_method', $window, 'prize_amount', 'submitted_at', 8, 'game_id'),
                'top_numbers' => $this->tenantPopularLotteryNumbersForWindow($tenantId, $window),
            ],
            'tables' => [
                'recent_orders' => $this->tenantRecentOrdersForWindow($tenantId, $window),
                'recent_wallet_ledger' => $this->tenantRecentWalletLedgerForWindow($tenantId, $window),
                'recent_reward_claims' => $this->tenantRecentRewardClaimsForWindow($tenantId, $window),
                'stock_summary' => $this->tenantStockSummaryRows($tenantId, $window),
                'popular_numbers' => $this->tenantPopularLotteryNumbersForWindow($tenantId, $window),
                'recent_rows' => $this->tenantRecentOrdersForWindow($tenantId, $window),
            ],
            'finance' => [
                'sales_amount' => $this->money($sales),
                'wallet_inflow' => $this->money($walletInflow),
                'wallet_outflow' => $this->money($walletOutflow),
                'wallet_net' => $this->money($walletInflow - $walletOutflow),
                'reward_payouts' => $this->money($rewardPayouts),
                'topups' => $this->money($this->tenantSumForWindow($tenantId, 'topup_requests', 'amount', $window)),
            ],
            'alerts' => $this->tenantDashboardAlerts($tenantId, $window),
        ];
    }

    /**
     * @return array<int, array{key: string, label: string}>
     */
    private function tenantDashboardPeriodOptions(): array
    {
        return [
            ['key' => 'today', 'label' => 'Today'],
            ['key' => 'yesterday', 'label' => 'Yesterday'],
            ['key' => 'last_7_days', 'label' => 'Last 7 days'],
            ['key' => 'current_draw', 'label' => 'Current draw'],
            ['key' => 'previous_draw', 'label' => 'Previous draw'],
        ];
    }

    /**
     * @return array<string, mixed>
     */
    private function tenantDashboardPeriod(string $period): array
    {
        $key = in_array($period, ['today', 'yesterday', 'last_7_days', 'current_draw', 'previous_draw'], true) ? $period : 'today';
        $now = CarbonImmutable::now();

        if ($key === 'current_draw') {
            return $this->centralDashboardGameWindow(
                $key,
                'Current draw',
                $this->centralDashboardCurrentGameRow(),
                'Current draw',
                $now,
            );
        }

        if ($key === 'previous_draw') {
            return $this->centralDashboardGameWindow(
                $key,
                'Previous draw',
                $this->centralDashboardPreviousGameRow($this->centralDashboardCurrentGameRow()),
                'Previous draw',
                $now,
            );
        }

        return $this->centralDashboardPeriod($key, 'sales');
    }

    private function tenantOrdersForWindow(?string $tenantId, array $window, bool $previous = false): ?\Illuminate\Database\Query\Builder
    {
        if ($tenantId === null || $tenantId === '') {
            return null;
        }

        $query = $this->paidOrdersQuery();
        if ($query === null) {
            return null;
        }

        $query->where('orders.tenant_id', $tenantId);
        $gameId = $previous ? $window['previous_game_id'] : $window['game_id'];
        if ($gameId !== null) {
            $query->where('orders.game_id', $gameId);
        } else {
            $this->applyTimeWindow($query, $window, 'orders.paid_at', $previous, 'orders.created_at');
        }

        return $query;
    }

    private function tenantOrdersSumForWindow(?string $tenantId, array $window, string $column, bool $previous = false): int
    {
        $query = $this->tenantOrdersForWindow($tenantId, $window, $previous);

        return $query === null || ! Schema::hasColumn('orders', $column) ? 0 : (int) $query->sum('orders.'.$column);
    }

    private function tenantOrdersCountForWindow(?string $tenantId, array $window, bool $previous = false): int
    {
        $query = $this->tenantOrdersForWindow($tenantId, $window, $previous);

        return $query === null ? 0 : (int) $query->count();
    }

    private function tenantOrdersCustomerCountForWindow(?string $tenantId, array $window, bool $previous = false): int
    {
        $query = $this->tenantOrdersForWindow($tenantId, $window, $previous);

        return $query === null ? 0 : (int) $query->whereNotNull('orders.customer_id')->distinct()->count('orders.customer_id');
    }

    private function tenantTicketsCountForWindow(?string $tenantId, array $window, bool $previous = false): int
    {
        if ($tenantId === null || $tenantId === '' || ! $this->tableExists('tickets') || ! $this->tableExists('orders')) {
            return 0;
        }

        $query = DB::table('tickets')
            ->join('orders', 'orders.id', '=', 'tickets.order_id')
            ->where('tickets.tenant_id', $tenantId)
            ->where('orders.tenant_id', $tenantId)
            ->where(function ($query): void {
                $query->where('orders.payment_status', 'paid')
                    ->orWhereNotNull('orders.paid_at')
                    ->orWhereIn('orders.status', ['paid', 'completed']);
            });

        $gameId = $previous ? $window['previous_game_id'] : $window['game_id'];
        if ($gameId !== null) {
            $query->where('tickets.game_id', $gameId);
        } else {
            $this->applyTimeWindow($query, $window, 'orders.paid_at', $previous, 'orders.created_at');
        }

        return (int) $query->count('tickets.id');
    }

    private function tenantCountForWindow(?string $tenantId, string $table, array $window, bool $previous = false, string $column = 'created_at', ?string $gameColumn = null): int
    {
        if ($tenantId === null || $tenantId === '' || ! $this->tableExists($table) || ! Schema::hasColumn($table, 'tenant_id') || ! Schema::hasColumn($table, $column)) {
            return 0;
        }

        $query = DB::table($table)->where($table.'.tenant_id', $tenantId);
        $gameId = $previous ? $window['previous_game_id'] : $window['game_id'];
        if ($gameColumn !== null && $gameId !== null && Schema::hasColumn($table, $gameColumn)) {
            $query->where($table.'.'.$gameColumn, $gameId);
        } else {
            $this->applyTimeWindow($query, $window, $table.'.'.$column, $previous, $column === 'created_at' ? null : $table.'.created_at');
        }

        return (int) $query->count();
    }

    private function tenantSumForWindow(
        ?string $tenantId,
        string $table,
        string $amountColumn,
        array $window,
        bool $previous = false,
        string $column = 'created_at',
        ?string $gameColumn = null,
    ): int {
        if (
            $tenantId === null
            || $tenantId === ''
            || ! $this->tableExists($table)
            || ! Schema::hasColumn($table, 'tenant_id')
            || ! Schema::hasColumn($table, $amountColumn)
            || ! Schema::hasColumn($table, $column)
        ) {
            return 0;
        }

        $query = DB::table($table)->where($table.'.tenant_id', $tenantId);
        $gameId = $previous ? $window['previous_game_id'] : $window['game_id'];
        if ($gameColumn !== null && $gameId !== null && Schema::hasColumn($table, $gameColumn)) {
            $query->where($table.'.'.$gameColumn, $gameId);
        } else {
            $this->applyTimeWindow($query, $window, $table.'.'.$column, $previous, $column === 'created_at' ? null : $table.'.created_at');
        }

        return (int) $query->sum($amountColumn);
    }

    private function tenantWalletLedgerFlowAmount(?string $tenantId, array $window, string $direction, bool $previous = false): int
    {
        if ($tenantId === null || $tenantId === '' || ! $this->tableExists('wallet_ledger')) {
            return 0;
        }

        $query = DB::table('wallet_ledger')->where('wallet_ledger.tenant_id', $tenantId);
        $this->applyTimeWindow($query, $window, 'wallet_ledger.posted_at', $previous, 'wallet_ledger.created_at');

        if (Schema::hasColumn('wallet_ledger', 'entry_type')) {
            if ($direction === 'outflow') {
                $query->whereIn('entry_type', ['debit', 'hold']);
            } else {
                $query->whereNotIn('entry_type', ['debit', 'hold']);
            }

            return (int) $query->sum(DB::raw('ABS(amount)'));
        }

        if ($direction === 'outflow') {
            $query->where('amount', '<', 0);

            return abs((int) $query->sum('amount'));
        }

        $query->where('amount', '>', 0);

        return (int) $query->sum('amount');
    }

    private function tenantStockCount(?string $tenantId, array $window, array $statuses = [], bool $previous = false): int
    {
        if ($tenantId === null || $tenantId === '' || ! $this->tableExists('local_stock_items')) {
            return 0;
        }

        $query = DB::table('local_stock_items')->where('tenant_id', $tenantId);
        $gameId = $previous ? $window['previous_game_id'] : $window['game_id'];
        if ($gameId !== null) {
            $query->where('game_id', $gameId);
        } else {
            $currentGame = $this->centralDashboardCurrentGameRow();
            if ($currentGame !== null) {
                $query->where('game_id', (string) $currentGame->id);
            }
        }
        if ($statuses !== []) {
            $query->whereIn('status', $statuses);
        }

        return (int) $query->count();
    }

    /**
     * @return array<int, array<string, mixed>>
     */
    private function tenantGroupedBreakdown(
        ?string $tenantId,
        string $table,
        string $groupColumn,
        array $window,
        string $amountColumn = '',
        string $dateColumn = 'created_at',
        int $limit = 8,
        ?string $gameColumn = null,
        bool $paidOrders = false,
    ): array {
        if (
            $tenantId === null
            || $tenantId === ''
            || ! $this->tableExists($table)
            || ! Schema::hasColumn($table, 'tenant_id')
            || ! Schema::hasColumn($table, $groupColumn)
            || ! Schema::hasColumn($table, $dateColumn)
        ) {
            return [];
        }

        $selectValue = $amountColumn !== '' && Schema::hasColumn($table, $amountColumn)
            ? DB::raw('SUM('.$table.'.'.$amountColumn.') as value')
            : DB::raw('COUNT(*) as value');
        $query = DB::table($table)
            ->where($table.'.tenant_id', $tenantId)
            ->select([$table.'.'.$groupColumn.' as label', $selectValue])
            ->groupBy($table.'.'.$groupColumn)
            ->orderByDesc('value')
            ->limit($limit);

        if ($paidOrders && $table === 'orders') {
            $query->where(function ($query): void {
                $query->where('orders.payment_status', 'paid')
                    ->orWhereNotNull('orders.paid_at')
                    ->orWhereIn('orders.status', ['paid', 'completed']);
            });
        }

        $gameId = $window['game_id'] ?? null;
        if ($gameColumn !== null && $gameId !== null && Schema::hasColumn($table, $gameColumn)) {
            $query->where($table.'.'.$gameColumn, $gameId);
        } else {
            $this->applyTimeWindow($query, $window, $table.'.'.$dateColumn, fallbackColumn: $dateColumn === 'created_at' ? null : $table.'.created_at');
        }

        return $query->get()
            ->map(fn (object $row): array => [
                'label' => $row->label === null || $row->label === '' ? 'Unknown' : $this->labelize((string) $row->label),
                'value' => (int) $row->value,
                'type' => $amountColumn !== '' ? 'money' : 'number',
            ])
            ->all();
    }

    /**
     * @return array<string, mixed>
     */
    private function tenantSalesTrendForWindow(?string $tenantId, array $window): array
    {
        $keys = $this->dashboardDateKeys($window);
        $sales = array_fill_keys($keys, 0);
        $orders = array_fill_keys($keys, 0);
        $tickets = array_fill_keys($keys, 0);

        if ($tenantId !== null && $tenantId !== '' && $this->tableExists('orders')) {
            $query = $this->tenantOrdersForWindow($tenantId, $window);
            if ($query !== null) {
                foreach ($query->get(['orders.total_amount', 'orders.paid_at', 'orders.created_at']) as $row) {
                    $day = $this->dayKey($row->paid_at ?? $row->created_at);
                    if (! array_key_exists($day, $sales)) {
                        continue;
                    }
                    $sales[$day] += (int) $row->total_amount;
                    $orders[$day]++;
                }
            }
        }

        if ($tenantId !== null && $tenantId !== '' && $this->tableExists('tickets') && $this->tableExists('orders')) {
            $query = DB::table('tickets')
                ->join('orders', 'orders.id', '=', 'tickets.order_id')
                ->where('tickets.tenant_id', $tenantId)
                ->where('orders.tenant_id', $tenantId)
                ->where(function ($query): void {
                    $query->where('orders.payment_status', 'paid')
                        ->orWhereNotNull('orders.paid_at')
                        ->orWhereIn('orders.status', ['paid', 'completed']);
                });
            if ($window['game_id'] !== null) {
                $query->where('tickets.game_id', $window['game_id']);
            } else {
                $this->applyTimeWindow($query, $window, 'orders.paid_at', fallbackColumn: 'orders.created_at');
            }

            foreach ($query->get(['orders.paid_at', 'orders.created_at']) as $row) {
                $day = $this->dayKey($row->paid_at ?? $row->created_at);
                if (array_key_exists($day, $tickets)) {
                    $tickets[$day]++;
                }
            }
        }

        return [
            'labels' => array_map(fn (string $day): string => CarbonImmutable::parse($day)->format('d M'), $keys),
            'keys' => $keys,
            'series' => [
                ['key' => 'sales_amount', 'label' => 'Sales', 'type' => 'money', 'values' => array_values($sales)],
                ['key' => 'paid_orders', 'label' => 'Paid orders', 'type' => 'number', 'values' => array_values($orders)],
                ['key' => 'tickets_sold', 'label' => 'Tickets sold', 'type' => 'number', 'values' => array_values($tickets)],
            ],
        ];
    }

    /**
     * @return array<string, mixed>
     */
    private function tenantWalletFlowTrendForWindow(?string $tenantId, array $window): array
    {
        $keys = $this->dashboardDateKeys($window);
        $inflow = array_fill_keys($keys, 0);
        $outflow = array_fill_keys($keys, 0);
        $topups = array_fill_keys($keys, 0);

        if ($tenantId !== null && $tenantId !== '' && $this->tableExists('wallet_ledger')) {
            $query = DB::table('wallet_ledger')->where('wallet_ledger.tenant_id', $tenantId);
            $this->applyTimeWindow($query, $window, 'wallet_ledger.posted_at', fallbackColumn: 'wallet_ledger.created_at');

            foreach ($query->get(['entry_type', 'amount', 'posted_at', 'created_at']) as $row) {
                $day = $this->dayKey($row->posted_at ?? $row->created_at);
                if (! array_key_exists($day, $inflow)) {
                    continue;
                }
                $amount = abs((int) $row->amount);
                if (in_array((string) $row->entry_type, ['debit', 'hold'], true) || (int) $row->amount < 0) {
                    $outflow[$day] += $amount;
                } else {
                    $inflow[$day] += $amount;
                }
            }
        }

        if ($tenantId !== null && $tenantId !== '' && $this->tableExists('topup_requests')) {
            $query = DB::table('topup_requests')->where('tenant_id', $tenantId);
            $this->applyTimeWindow($query, $window, 'topup_requests.created_at');

            foreach ($query->get(['amount', 'created_at']) as $row) {
                $day = $this->dayKey($row->created_at);
                if (array_key_exists($day, $topups)) {
                    $topups[$day] += (int) $row->amount;
                }
            }
        }

        return [
            'labels' => array_map(fn (string $day): string => CarbonImmutable::parse($day)->format('d M'), $keys),
            'keys' => $keys,
            'series' => [
                ['key' => 'wallet_inflow', 'label' => 'Inflow', 'type' => 'money', 'values' => array_values($inflow)],
                ['key' => 'wallet_outflow', 'label' => 'Outflow', 'type' => 'money', 'values' => array_values($outflow)],
                ['key' => 'topups', 'label' => 'Topups', 'type' => 'money', 'values' => array_values($topups)],
            ],
        ];
    }

    /**
     * @return array<int, array<string, mixed>>
     */
    private function tenantStockStatusBreakdown(?string $tenantId, array $window): array
    {
        if ($tenantId === null || $tenantId === '' || ! $this->tableExists('local_stock_items')) {
            return [];
        }

        $query = DB::table('local_stock_items')
            ->where('tenant_id', $tenantId)
            ->select(['status', DB::raw('COUNT(*) as row_count')])
            ->groupBy('status')
            ->orderByDesc('row_count');

        $gameId = $window['game_id'] ?? null;
        if ($gameId !== null) {
            $query->where('game_id', $gameId);
        } else {
            $currentGame = $this->centralDashboardCurrentGameRow();
            if ($currentGame !== null) {
                $query->where('game_id', (string) $currentGame->id);
            }
        }

        return $query->get()
            ->map(fn (object $row): array => [
                'label' => $this->labelize((string) ($row->status ?? 'unknown')),
                'value' => (int) $row->row_count,
                'type' => 'number',
            ])
            ->all();
    }

    /**
     * @return array<int, array<string, mixed>>
     */
    private function tenantStockSummaryRows(?string $tenantId, array $window): array
    {
        $breakdown = $this->tenantStockStatusBreakdown($tenantId, $window);
        $total = array_sum(array_map(fn (array $row): int => (int) $row['value'], $breakdown));

        return array_map(fn (array $row): array => [
            'status' => $row['label'],
            'count' => (int) $row['value'],
            'percent' => $total > 0 ? round(((int) $row['value'] / $total) * 100, 2) : 0,
        ], $breakdown);
    }

    /**
     * @return array<string, array<int, array<string, mixed>>>
     */
    private function tenantPopularLotteryNumbersForWindow(?string $tenantId, array $window): array
    {
        return [
            'back2' => $this->tenantPopularTicketNumberSegment($tenantId, $window, 'back2', '2 ท้าย', 'RIGHT(tickets.full_number, 2)'),
            'back3' => $this->tenantPopularTicketNumberSegment($tenantId, $window, 'back3', '3 ท้าย', 'RIGHT(tickets.full_number, 3)'),
            'front3' => $this->tenantPopularTicketNumberSegment($tenantId, $window, 'front3', '3 หน้า', 'LEFT(tickets.full_number, 3)'),
        ];
    }

    /**
     * @return array<int, array<string, mixed>>
     */
    private function tenantPopularTicketNumberSegment(?string $tenantId, array $window, string $key, string $label, string $expression): array
    {
        if ($tenantId === null || $tenantId === '' || ! $this->tableExists('tickets') || ! $this->tableExists('orders')) {
            return [];
        }

        $rows = $this->tenantPopularTicketNumberQuery($tenantId, $window)
            ->select([
                DB::raw($expression.' as number'),
                DB::raw('COUNT(tickets.id) as ticket_count'),
                DB::raw('COALESCE(SUM(orders.total_amount), 0) as sales_amount'),
            ])
            ->groupBy('number')
            ->orderByDesc('ticket_count')
            ->orderBy('number')
            ->limit(10)
            ->get();

        return $rows->map(fn (object $row): array => [
            'key' => $key,
            'label' => $label,
            'number' => (string) $row->number,
            'ticket_count' => (int) $row->ticket_count,
            'sales_amount' => $this->money((int) $row->sales_amount),
            'value' => (int) $row->ticket_count,
        ])->all();
    }

    private function tenantPopularTicketNumberQuery(string $tenantId, array $window): \Illuminate\Database\Query\Builder
    {
        $query = DB::table('tickets')
            ->join('orders', 'orders.id', '=', 'tickets.order_id')
            ->where('tickets.tenant_id', $tenantId)
            ->where('orders.tenant_id', $tenantId)
            ->where(function ($query): void {
                $query->where('orders.payment_status', 'paid')
                    ->orWhereNotNull('orders.paid_at')
                    ->orWhereIn('orders.status', ['paid', 'completed']);
            });

        if ($window['game_id'] !== null) {
            $query->where('tickets.game_id', $window['game_id']);
        } else {
            $this->applyTimeWindow($query, $window, 'orders.paid_at', fallbackColumn: 'orders.created_at');
        }

        return $query;
    }

    /**
     * @return array<int, array<string, mixed>>
     */
    private function tenantRecentOrdersForWindow(?string $tenantId, array $window): array
    {
        if ($tenantId === null || $tenantId === '' || ! $this->tableExists('orders')) {
            return [];
        }

        $query = $this->tenantOrdersForWindow($tenantId, $window);
        if ($query === null) {
            return [];
        }

        return $query
            ->leftJoin('customers', 'customers.id', '=', 'orders.customer_id')
            ->select(['orders.id', 'orders.reference', 'orders.total_amount', 'orders.payment_method', 'orders.payment_status', 'orders.paid_at', 'orders.created_at', 'customers.name as customer_name', 'customers.phone as customer_phone'])
            ->orderByRaw('COALESCE(orders.paid_at, orders.created_at) DESC')
            ->limit(12)
            ->get()
            ->map(fn (object $row): array => [
                'id' => (string) $row->id,
                'reference' => (string) ($row->reference ?: $row->id),
                'customer' => (string) ($row->customer_name ?: $row->customer_phone ?: 'Customer'),
                'status' => (string) $row->payment_status,
                'payment_method' => $this->labelize((string) $row->payment_method),
                'amount' => $this->money((int) $row->total_amount),
                'created_at' => $this->isoDate($row->paid_at ?? $row->created_at),
            ])
            ->all();
    }

    /**
     * @return array<int, array<string, mixed>>
     */
    private function tenantRecentWalletLedgerForWindow(?string $tenantId, array $window): array
    {
        if ($tenantId === null || $tenantId === '' || ! $this->tableExists('wallet_ledger')) {
            return [];
        }

        $query = DB::table('wallet_ledger')
            ->where('wallet_ledger.tenant_id', $tenantId)
            ->leftJoin('customers', 'customers.id', '=', 'wallet_ledger.customer_id')
            ->select(['wallet_ledger.id', 'wallet_ledger.entry_type', 'wallet_ledger.status', 'wallet_ledger.amount', 'wallet_ledger.balance_after', 'wallet_ledger.posted_at', 'wallet_ledger.created_at', 'customers.name as customer_name', 'customers.phone as customer_phone'])
            ->orderByRaw('COALESCE(wallet_ledger.posted_at, wallet_ledger.created_at) DESC')
            ->limit(12);
        $this->applyTimeWindow($query, $window, 'wallet_ledger.posted_at', fallbackColumn: 'wallet_ledger.created_at');

        return $query->get()
            ->map(fn (object $row): array => [
                'id' => (string) $row->id,
                'entry_type' => $this->labelize((string) $row->entry_type),
                'customer' => (string) ($row->customer_name ?: $row->customer_phone ?: 'Customer'),
                'status' => (string) $row->status,
                'amount' => $this->money((int) $row->amount),
                'balance_after' => $this->money((int) $row->balance_after),
                'created_at' => $this->isoDate($row->posted_at ?? $row->created_at),
            ])
            ->all();
    }

    /**
     * @return array<int, array<string, mixed>>
     */
    private function tenantRecentRewardClaimsForWindow(?string $tenantId, array $window): array
    {
        if ($tenantId === null || $tenantId === '' || ! $this->tableExists('reward_claims')) {
            return [];
        }

        $query = DB::table('reward_claims')
            ->where('reward_claims.tenant_id', $tenantId)
            ->leftJoin('customers', 'customers.id', '=', 'reward_claims.customer_id')
            ->select(['reward_claims.id', 'reward_claims.status', 'reward_claims.payout_method', 'reward_claims.prize_amount', 'reward_claims.submitted_at', 'reward_claims.paid_at', 'reward_claims.created_at', 'customers.name as customer_name', 'customers.phone as customer_phone'])
            ->orderByRaw('COALESCE(reward_claims.paid_at, reward_claims.submitted_at, reward_claims.created_at) DESC')
            ->limit(12);
        if ($window['game_id'] !== null) {
            $query->where('reward_claims.game_id', $window['game_id']);
        } else {
            $this->applyTimeWindow($query, $window, 'reward_claims.submitted_at', fallbackColumn: 'reward_claims.created_at');
        }

        return $query->get()
            ->map(fn (object $row): array => [
                'id' => (string) $row->id,
                'customer' => (string) ($row->customer_name ?: $row->customer_phone ?: 'Customer'),
                'status' => (string) $row->status,
                'payout_method' => $this->labelize((string) $row->payout_method),
                'amount' => $this->money((int) $row->prize_amount),
                'created_at' => $this->isoDate($row->paid_at ?? $row->submitted_at ?? $row->created_at),
            ])
            ->all();
    }

    /**
     * @return array<int, array<string, mixed>>
     */
    private function tenantDashboardAlerts(?string $tenantId, array $window): array
    {
        if ($tenantId === null || $tenantId === '') {
            return [];
        }

        $alerts = [];
        $pendingClaims = $this->tenantPendingRewardClaimsCountForWindow($tenantId, $window);
        $availableStock = $this->tenantStockCount($tenantId, $window, ['available']);

        if ($pendingClaims > 0) {
            $alerts[] = [
                'severity' => 'warning',
                'title' => 'Reward claims need review',
                'message' => number_format($pendingClaims).' claims are in this filter period.',
                'value' => $pendingClaims,
            ];
        }

        if ($availableStock > 0 && $availableStock < 100) {
            $alerts[] = [
                'severity' => 'info',
                'title' => 'Low available stock',
                'message' => 'Available stock for the selected draw is below 100 tickets.',
                'value' => $availableStock,
            ];
        }

        return $alerts;
    }

    private function tenantPendingRewardClaimsCountForWindow(string $tenantId, array $window): int
    {
        if (! $this->tableExists('reward_claims')) {
            return 0;
        }

        $query = DB::table('reward_claims')
            ->where('tenant_id', $tenantId)
            ->whereIn('status', ['submitted', 'under_review']);

        if ($window['game_id'] !== null) {
            $query->where('game_id', $window['game_id']);
        } else {
            $this->applyTimeWindow($query, $window, 'reward_claims.submitted_at', fallbackColumn: 'reward_claims.created_at');
        }

        return (int) $query->count();
    }

    /**
     * @return array<string, mixed>
     */
    private function tenantDashboardKpis(?string $tenantId, array $window): array
    {
        $walletInflow = $this->tenantWalletLedgerFlowAmount($tenantId, $window, 'inflow');
        $walletOutflow = $this->tenantWalletLedgerFlowAmount($tenantId, $window, 'outflow');

        return [
            'admin_users_total' => AdminUserRole::query()
                ->join('admin_scopes', 'admin_scopes.id', '=', 'admin_user_roles.scope_id')
                ->where('admin_scopes.scope_type', 'tenant')
                ->where('admin_scopes.tenant_id', $tenantId)
                ->distinct('admin_user_roles.admin_user_id')
                ->count('admin_user_roles.admin_user_id'),
            'roles_total' => Role::where('scope_type', 'tenant')
                ->where('tenant_id', $tenantId)
                ->count(),
            'menus_total' => AdminMenu::where('scope_type', 'tenant')->count(),
            'audit_logs_total' => AuditLog::where('scope_type', 'tenant')
                ->where('tenant_id', $tenantId)
                ->count(),
            'orders_total' => $this->tenantOrdersCountForWindow($tenantId, $window),
            'tickets_total' => $this->tenantTicketsCountForWindow($tenantId, $window),
            'topups_total' => $this->tenantCountForWindow($tenantId, 'topup_requests', $window),
            'sales_amount' => $this->money($this->tenantOrdersSumForWindow($tenantId, $window, 'total_amount')),
            'paid_customers' => $this->tenantOrdersCustomerCountForWindow($tenantId, $window),
            'wallet_inflow_amount' => $this->money($walletInflow),
            'wallet_outflow_amount' => $this->money($walletOutflow),
            'wallet_net_amount' => $this->money($walletInflow - $walletOutflow),
            'wallet_balance_amount' => $this->money($this->sumTable('wallets', 'balance_amount', fn ($query) => $query->where('tenant_id', $tenantId)->where('status', 'active'))),
            'reward_claims_total' => $this->tenantCountForWindow($tenantId, 'reward_claims', $window, column: 'submitted_at', gameColumn: 'game_id'),
            'pending_reward_claims' => $this->countTable('reward_claims', fn ($query) => $query->where('tenant_id', $tenantId)->whereIn('status', ['submitted', 'under_review'])),
            'reward_payouts_amount' => $this->money($this->tenantSumForWindow($tenantId, 'reward_claims', 'prize_amount', $window, column: 'paid_at', gameColumn: 'game_id')),
            'stock_available' => $this->tenantStockCount($tenantId, $window, ['available']),
            'stock_reserved' => $this->tenantStockCount($tenantId, $window, ['reserved']),
            'stock_sold' => $this->tenantStockCount($tenantId, $window, ['sold']),
            'customers_total' => $this->countTable('customers', fn ($query) => $query->where('tenant_id', $tenantId)),
            'new_customers' => $this->tenantCountForWindow($tenantId, 'customers', $window),
            'affiliate_accounts_total' => $this->countTable('affiliate_accounts', fn ($query) => $query->where('tenant_id', $tenantId)),
            'new_affiliate_accounts' => $this->tenantCountForWindow($tenantId, 'affiliate_accounts', $window),
        ];
    }

    private function isAllowedAdminChannel(AdminSessionContext $context, string $scopeType, string $channelName): bool
    {
        $adminUserId = $context->adminUser['id'];

        if ($scopeType === 'central') {
            return in_array($channelName, [
                'private-admin.central',
                'presence-admin.central',
                'private-admin.central.dashboard',
                'private-admin.central.audit',
                'private-admin.central.menu',
                'private-admin.central.admin.'.$adminUserId,
                'presence-admin.central.admin.'.$adminUserId,
            ], true) || $this->isCentralStockGenerationChannel($channelName)
                || $this->isCentralStockCoverageChannel($channelName)
                || $this->isCentralStockTableChannel($channelName);
        }

        $tenantId = $context->activeTenantId();

        if ($tenantId === null || $tenantId === '') {
            return false;
        }

        return in_array($channelName, [
            'private-admin.tenant.'.$tenantId,
            'presence-admin.tenant.'.$tenantId,
            'private-admin.tenant.'.$tenantId.'.dashboard',
            'private-admin.tenant.'.$tenantId.'.audit',
            'private-admin.tenant.'.$tenantId.'.menu',
            'private-admin.tenant.'.$tenantId.'.admin.'.$adminUserId,
            'presence-admin.tenant.'.$tenantId.'.admin.'.$adminUserId,
        ], true) || $this->isTenantStockChannel($channelName, $tenantId)
            || $this->isTenantStockCoverageChannel($channelName, $tenantId)
            || $this->isTenantTopupsChannel($channelName, $tenantId)
            || $this->isTenantRewardClaimsChannel($channelName, $tenantId);
    }

    private function isCentralStockGenerationChannel(string $channelName): bool
    {
        return $channelName === 'private-admin.central.stock-generation'
            || preg_match('/^private-admin\.central\.stock-generation\.game\.[A-Za-z0-9_-]+$/', $channelName) === 1
            || preg_match('/^private-admin\.central\.stock-generation\.batch\.[A-Za-z0-9_-]+$/', $channelName) === 1;
    }

    private function isCentralStockCoverageChannel(string $channelName): bool
    {
        return preg_match('/^private-admin\.central\.stock\.coverage\.game\.[A-Za-z0-9_-]+$/', $channelName) === 1;
    }

    private function isCentralStockTableChannel(string $channelName): bool
    {
        return preg_match('/^private-admin\.central\.stock\.table\.game\.[A-Za-z0-9_-]+$/', $channelName) === 1;
    }

    private function isTenantStockChannel(string $channelName, ?string $tenantId = null): bool
    {
        $tenantPattern = $tenantId === null || $tenantId === ''
            ? '[A-Za-z0-9_-]+'
            : preg_quote($tenantId, '/');

        return preg_match('/^private-admin\.tenant\.'.$tenantPattern.'\.stock\.game\.[A-Za-z0-9_-]+$/', $channelName) === 1;
    }

    private function isTenantStockCoverageChannel(string $channelName, ?string $tenantId = null): bool
    {
        $tenantPattern = $tenantId === null || $tenantId === ''
            ? '[A-Za-z0-9_-]+'
            : preg_quote($tenantId, '/');

        return preg_match('/^private-admin\.tenant\.'.$tenantPattern.'\.stock\.coverage\.game\.[A-Za-z0-9_-]+$/', $channelName) === 1;
    }

    private function isTenantTopupsChannel(string $channelName, ?string $tenantId = null): bool
    {
        $tenantPattern = $tenantId === null || $tenantId === ''
            ? '[A-Za-z0-9_-]+'
            : preg_quote($tenantId, '/');

        return preg_match('/^private-admin\.tenant\.'.$tenantPattern.'\.topups$/', $channelName) === 1;
    }

    private function isTenantRewardClaimsChannel(string $channelName, ?string $tenantId = null): bool
    {
        $tenantPattern = $tenantId === null || $tenantId === ''
            ? '[A-Za-z0-9_-]+'
            : preg_quote($tenantId, '/');

        return preg_match('/^private-admin\.tenant\.'.$tenantPattern.'\.reward-claims$/', $channelName) === 1;
    }

    private function limit(mixed $value): int
    {
        $limit = filter_var($value, FILTER_VALIDATE_INT);

        if ($limit === false) {
            return 50;
        }

        return max(1, min(100, $limit));
    }

    /**
     * @return array{id: string, created_at: string}|null
     */
    private function decodeCursor(mixed $cursor): ?array
    {
        if (! is_string($cursor) || trim($cursor) === '') {
            return null;
        }

        $decoded = base64_decode($cursor, true);

        if ($decoded === false) {
            return null;
        }

        $payload = json_decode($decoded, true);

        if (! is_array($payload) || ! is_string($payload['id'] ?? null) || ! is_string($payload['created_at'] ?? null)) {
            return null;
        }

        return [
            'id' => $payload['id'],
            'created_at' => $payload['created_at'],
        ];
    }

    private function encodeCursor(object $row): string
    {
        return base64_encode(json_encode([
            'id' => (string) $row->id,
            'created_at' => (string) $row->created_at,
        ], JSON_THROW_ON_ERROR));
    }

    /**
     * @return array<string, mixed>
     */
    private function auditLogResource(object $row): array
    {
        $payload = [];

        if ($row->payload_redacted_json !== null) {
            $decoded = is_array($row->payload_redacted_json)
                ? $row->payload_redacted_json
                : json_decode((string) $row->payload_redacted_json, true);
            $payload = is_array($decoded) ? $this->auditLogger->redactPayload($decoded) : [];
        }

        return [
            'id' => (string) $row->id,
            'tenant_id' => $row->tenant_id,
            'status' => null,
            'created_at' => $row->created_at,
            'updated_at' => $row->updated_at,
            'scope' => (string) $row->scope_type,
            'actor_type' => (string) $row->actor_type,
            'actor_id' => (string) $row->actor_id,
            'partner_id' => $row->partner_id,
            'action' => (string) $row->action,
            'target_type' => $row->target_type,
            'target_id' => $row->target_id,
            'request_id' => $row->request_id,
            'payload' => $payload,
        ];
    }
}
