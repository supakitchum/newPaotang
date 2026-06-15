<?php

namespace App\Modules\Reward\Services;

use App\Models\Customer;
use App\Models\Game;
use App\Models\RewardCheckBatch;
use App\Models\RewardCheckItem;
use App\Models\RewardClaim;
use App\Models\RewardPrize;
use App\Models\RewardPublishLog;
use App\Models\RewardResult;
use App\Models\PlatformSystemSetting;
use App\Models\PartnerTenant;
use App\Models\SyncOutbox;
use App\Models\Ticket;
use App\Models\Wallet;
use App\Models\WinningTicket;
use App\Jobs\ProcessTenantActivitiesForGameJob;
use App\Modules\Reward\Events\RewardClaimUpdated;
use App\Modules\Reward\Events\RewardLiveResultUpdated;
use App\Modules\Rbac\Events\AdminMenuBadgesUpdated;
use App\Shared\Audit\AuditLogger;
use App\Shared\Auth\AdminSessionContext;
use App\Modules\Auth\Services\CustomerAuthService;
use App\Shared\Auth\CustomerSessionContext;
use App\Modules\Commerce\Services\CommerceService;
use App\Modules\LineNotifications\Services\TenantLineNotificationService;
use App\Modules\TelegramNotifications\Services\CentralTelegramNotificationService;
use App\Shared\Idempotency\IdempotencyService;
use App\Support\CustomerNo;
use App\Support\PublicUrl;
use App\Support\YoutubeLiveUrl;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Schema;
use Illuminate\Support\Str;

class RewardService
{
    private const CHECK_CHUNK_SIZE = 100;
    private const PUBLIC_LIVE_RESULT_STATUSES = ['draft', 'recorded', 'checking', 'summary_ready', 'verified', 'published'];
    private const PUBLIC_RESULT_GAME_STATUSES = ['closed', 'reward_recorded', 'reward_checking', 'reward_verified', 'reward_published'];
    private const CLOSED_GAME_STATUSES = ['closed', 'reward_recorded', 'reward_checking', 'reward_verified', 'reward_published'];
    private const PENDING_CLAIM_STATUSES = ['submitted', 'under_review'];
    private const PRIZE_TYPE_SORT_ORDER = [
        'first_prize' => 10,
        'near_first_prize' => 20,
        'second_prize' => 30,
        'third_prize' => 40,
        'fourth_prize' => 50,
        'fifth_prize' => 60,
        'front3' => 70,
        'back3' => 80,
        'back2' => 90,
    ];
    public const CLAIM_PAYOUT_METHODS = ['wallet_credit', 'bank_transfer', 'manual_cash'];

    public function __construct(
        private readonly AuditLogger $auditLogger,
        private readonly IdempotencyService $idempotency,
        private readonly CustomerAuthService $customerAuth,
        private readonly CommerceService $commerce,
        private readonly TenantRewardPriceRuleService $tenantRewardPriceRules,
        private readonly TenantLineNotificationService $lineNotifications,
        private readonly CentralTelegramNotificationService $telegramNotifications,
    ) {
    }

    /**
     * @param array<string, mixed> $payload
     * @return array<string, array<int, string>>
     */
    public function validateRewardPayload(array $payload, bool $creating = true, ?string $rewardResultId = null): array
    {
        $errors = [];
        $gameId = trim((string) ($payload['game_id'] ?? ''));

        if ($creating && ($gameId === '' || ! Game::whereKey($gameId)->exists())) {
            $errors['game_id'][] = 'The game_id field must reference an existing game.';
        }

        if ($creating && $gameId !== '') {
            $status = Game::whereKey($gameId)->value('status');

            if (! in_array((string) $status, ['closed', 'reward_recorded', 'reward_checking', 'reward_verified', 'reward_published'], true)) {
                $errors['game_id'][] = 'The game must be closed before reward results can be recorded.';
            }
        }

        if (! $creating && $rewardResultId !== null && $this->hasResultRecordingPayload($payload)) {
            $result = RewardResult::query()->whereKey($rewardResultId)->first();
            $status = $result === null ? null : Game::whereKey($result->game_id)->value('status');

            if ($result !== null && ! in_array((string) $status, ['closed', 'reward_recorded', 'reward_checking', 'reward_verified', 'reward_published'], true)) {
                $errors['game_id'][] = 'The game must be closed before reward results can be recorded.';
            }
        }

        if (! $creating && ! $this->hasRewardUpdatePayload($payload)) {
            $errors['prizes'][] = 'The prizes, prize_number_updates, or payout_amount_updates field is required to update Thai Government Lottery rewards.';

            return $errors;
        }

        if (! $creating && ! array_key_exists('prizes', $payload)) {
            $errors = $this->mergeFieldErrors($errors, $this->validatePartialRewardUpdates($payload, $rewardResultId));

            return $errors;
        }

        $prizes = $payload['prizes'] ?? null;

        if (! is_array($prizes) || $prizes === []) {
            $errors['prizes'][] = 'The prizes field must contain at least one prize.';

            return $errors;
        }

        return $this->mergeFieldErrors($errors, $this->validatePrizeRows($prizes, true));
    }

    /**
     * @param array<int, mixed> $prizes
     * @return array<string, array<int, string>>
     */
    private function validatePrizeRows(array $prizes, bool $requireComplete, bool $requireExactCounts = true): array
    {
        $errors = [];
        $seen = [];
        $amountsByType = [];
        $rules = ThaiGovernmentLotteryRewardTemplate::rules();
        $counts = array_fill_keys(array_keys($rules), 0);

        foreach (array_values($prizes) as $index => $prize) {
            if (! is_array($prize)) {
                $errors["prizes.$index"][] = 'The prize row is invalid.';
                continue;
            }

            $type = trim((string) ($prize['prize_type'] ?? ''));
            $number = trim((string) ($prize['prize_number'] ?? ''));
            $amount = $this->moneyAmount($prize['amount'] ?? null, 0);
            $currency = $this->moneyCurrency($prize['amount'] ?? null);
            $rule = $rules[$type] ?? null;
            $key = $type.':'.$number;

            if ($type === '') {
                $errors["prizes.$index.prize_type"][] = 'The prize_type field is required.';
            } elseif ($rule === null) {
                $errors["prizes.$index.prize_type"][] = 'The prize_type field must be a Thai Government Lottery prize type.';
            } else {
                $counts[$type]++;
            }

            if ($this->isPendingPrizeNumber($number)) {
                if (! $requireComplete) {
                    continue;
                }

                $errors["prizes.$index.prize_number"][] = 'The prize_number field is required.';
            } elseif ($rule !== null && ! preg_match('/^[0-9]{'.$rule['digits'].'}$/', $number)) {
                $errors["prizes.$index.prize_number"][] = 'The '.$type.' prize_number field must contain exactly '.$rule['digits'].' digits.';
            }

            if ($amount <= 0) {
                $errors["prizes.$index.amount"][] = 'The amount field must be greater than zero.';
            } elseif ($rule !== null) {
                if (! isset($amountsByType[$type])) {
                    $amountsByType[$type] = $amount;
                } elseif ($amountsByType[$type] !== $amount) {
                    $errors["prizes.$index.amount"][] = 'The '.$type.' amount must be the same for every row in the prize group.';
                }
            }

            if ($currency !== ThaiGovernmentLotteryRewardTemplate::CURRENCY) {
                $errors["prizes.$index.amount"][] = 'The amount currency must be THB.';
            }

            if (! $this->isPendingPrizeNumber($number) && isset($seen[$key])) {
                $errors["prizes.$index"][] = 'Duplicate prize rows are not allowed.';
            }

            if (! $this->isPendingPrizeNumber($number)) {
                $seen[$key] = true;
            }
        }

        if ($requireExactCounts) {
            foreach ($rules as $type => $rule) {
                if (($counts[$type] ?? 0) !== $rule['count']) {
                    $errors['prizes'][] = 'Thai Government Lottery rewards require '.$rule['count'].' '.$type.' row(s).';
                }
            }
        }

        return $errors;
    }

    /**
     * @param array<string, mixed> $payload
     * @return array<string, array<int, string>>
     */
    private function validatePartialRewardUpdates(array $payload, ?string $rewardResultId): array
    {
        $errors = [];
        $hasUpdate = false;
        $rules = ThaiGovernmentLotteryRewardTemplate::rules();

        if (array_key_exists('prize_number_updates', $payload)) {
            $updates = $payload['prize_number_updates'];

            if (! is_array($updates) || $updates === []) {
                $errors['prize_number_updates'][] = 'The prize_number_updates field must contain at least one prize group.';
            } else {
                foreach (array_values($updates) as $index => $update) {
                    $row = is_array($update) ? $update : [];
                    $type = trim((string) ($row['prize_type'] ?? ''));
                    $numbers = $row['prize_numbers'] ?? [];
                    $rule = $rules[$type] ?? null;

                    if ($type === '' || $rule === null) {
                        $errors["prize_number_updates.$index.prize_type"][] = 'The prize_type field must be a Thai Government Lottery prize type.';
                        continue;
                    }

                    if (! is_array($numbers) || $numbers === []) {
                        $errors["prize_number_updates.$index.prize_numbers"][] = 'The prize_numbers field must contain at least one prize number.';
                        continue;
                    }

                    if (count($numbers) > $rule['count']) {
                        $errors["prize_number_updates.$index.prize_numbers"][] = 'The '.$type.' prize_numbers field cannot contain more than '.$rule['count'].' number(s).';
                    }

                    foreach (array_values($numbers) as $numberIndex => $number) {
                        $normalizedNumber = trim((string) $number);
                        $hasUpdate = true;

                        if ($this->isPendingPrizeNumber($normalizedNumber)) {
                            continue;
                        }

                        if (! preg_match('/^[0-9]{'.$rule['digits'].'}$/', $normalizedNumber)) {
                            $errors["prize_number_updates.$index.prize_numbers.$numberIndex"][] = 'The '.$type.' prize number must contain exactly '.$rule['digits'].' digits.';
                        }
                    }
                }
            }
        }

        if (array_key_exists('payout_amount_updates', $payload)) {
            $updates = $payload['payout_amount_updates'];

            if (! is_array($updates) || $updates === []) {
                $errors['payout_amount_updates'][] = 'The payout_amount_updates field must contain at least one prize group.';
            } else {
                foreach (array_values($updates) as $index => $update) {
                    $row = is_array($update) ? $update : [];
                    $type = trim((string) ($row['prize_type'] ?? ''));
                    $amount = $this->moneyAmount($row['amount'] ?? null, 0);
                    $currency = $this->moneyCurrency($row['amount'] ?? null);

                    if ($type === '' || ! isset($rules[$type])) {
                        $errors["payout_amount_updates.$index.prize_type"][] = 'The prize_type field must be a Thai Government Lottery prize type.';
                    }

                    if ($amount <= 0) {
                        $errors["payout_amount_updates.$index.amount"][] = 'The amount field must be greater than zero.';
                    } else {
                        $hasUpdate = true;
                    }

                    if ($currency !== ThaiGovernmentLotteryRewardTemplate::CURRENCY) {
                        $errors["payout_amount_updates.$index.amount"][] = 'The amount currency must be THB.';
                    }
                }
            }
        }

        if (! $hasUpdate && $errors === []) {
            $errors['prizes'][] = 'At least one prize number or payout amount update is required.';
        }

        if ($errors !== [] || $rewardResultId === null) {
            return $errors;
        }

        $existing = $this->rewardPrizePayloadRows($rewardResultId);

        if ($existing === []) {
            return ['prizes' => ['The reward result must have draft prize rows before partial updates can be applied.']];
        }

        $merged = $this->applyPartialRewardUpdatesToRows($existing, $this->normalizePartialRewardUpdates($payload));

        return $this->mergeFieldErrors($errors, $this->validatePrizeRows($merged, false));
    }

    /**
     * @param array<string, mixed> $queryParams
     * @return array<string, mixed>
     */
    public function listRewardResults(array $queryParams): array
    {
        $limit = $this->limit($queryParams['limit'] ?? null);
        $query = RewardResult::query()
            ->orderBy('id')
            ->limit($limit + 1);

        foreach (['game_id', 'status'] as $field) {
            if (($queryParams[$field] ?? null) !== null && trim((string) $queryParams[$field]) !== '') {
                $query->where($field, trim((string) $queryParams[$field]));
            }
        }

        if (($queryParams['cursor'] ?? null) !== null && trim((string) $queryParams['cursor']) !== '') {
            $query->where('id', '>', trim((string) $queryParams['cursor']));
        }

        $rows = $query->get()->all();
        $hasMore = count($rows) > $limit;
        $rows = array_slice($rows, 0, $limit);

        return [
            'data' => array_map(fn (object $result): array => $this->rewardResultResource($result), $rows),
            'meta' => [
                'next_cursor' => $hasMore && $rows !== [] ? (string) end($rows)->id : null,
                'has_more' => $hasMore,
                'live_settings' => $this->centralLiveSettings(),
            ],
        ];
    }

    /**
     * @param array<string, mixed> $queryParams
     * @return array<string, mixed>
     */
    public function listCentralWinners(array $queryParams): array
    {
        return $this->listWinners($queryParams);
    }

    /**
     * @param array<string, mixed> $queryParams
     * @return array<string, mixed>
     */
    public function listTenantWinners(string $tenantId, array $queryParams): array
    {
        return $this->listWinners($queryParams, $tenantId);
    }

    /**
     * @param array<string, mixed> $queryParams
     * @return array<string, mixed>
     */
    private function listWinners(array $queryParams, ?string $tenantId = null): array
    {
        $limit = $this->limit($queryParams['limit'] ?? null);
        $defaultGameId = $this->defaultWinnerGameId($tenantId);
        $gameId = trim((string) ($queryParams['game_id'] ?? ''));
        $gameId = $gameId === '' ? (string) ($defaultGameId ?? '') : $gameId;
        $game = $gameId === '' ? null : Game::query()->whereKey($gameId)->first();

        if ($game === null) {
            return [
                'data' => [],
                'meta' => [
                    'game_id' => $gameId === '' ? null : $gameId,
                    'default_game_id' => $defaultGameId,
                    'game' => null,
                    'scope_type' => $tenantId === null ? 'central' : 'tenant',
                    'tenant_id' => $tenantId,
                    'winner_count' => 0,
                    'total_prize_amount' => $this->money(0),
                    'next_cursor' => null,
                    'has_more' => false,
                ],
            ];
        }

        $liveResult = $this->latestDraftWinnerPreviewResultForGame((string) $game->id);
        if ($liveResult !== null) {
            $liveWinners = $this->centralWinnerLiveRows($liveResult, $game, $limit, $tenantId);
            $liveResultSummary = $this->publicLiveSummary($liveResult);

            return [
                'data' => $liveWinners['rows'],
                'meta' => $this->centralWinnerLiveMeta(
                    $game,
                    $defaultGameId,
                    $liveResultSummary,
                    $liveResultSummary['live_estimate'],
                    $liveWinners['winning_ticket_count'],
                    $liveWinners['winning_row_count'],
                    $liveWinners['by_prize_type'],
                    true,
                    $liveWinners['total_prize_amount'],
                    $tenantId,
                ),
            ];
        }

        $baseQuery = DB::table('winning_tickets')
            ->leftJoin('tickets', 'tickets.id', '=', 'winning_tickets.ticket_id')
            ->leftJoin('customers', 'customers.id', '=', 'tickets.customer_id')
            ->leftJoin('partner_tenants', 'partner_tenants.id', '=', 'winning_tickets.tenant_id')
            ->leftJoin('reward_claims', 'reward_claims.winning_ticket_id', '=', 'winning_tickets.id')
            ->where('winning_tickets.game_id', $gameId);

        if ($tenantId !== null) {
            $baseQuery->where('winning_tickets.tenant_id', $tenantId);
        }

        foreach (['status', 'prize_type', 'tenant_id'] as $field) {
            if (($queryParams[$field] ?? null) !== null && trim((string) $queryParams[$field]) !== '') {
                $baseQuery->where('winning_tickets.'.$field, trim((string) $queryParams[$field]));
            }
        }

        if (($queryParams['claim_status'] ?? null) !== null && trim((string) $queryParams['claim_status']) !== '') {
            $claimStatus = trim((string) $queryParams['claim_status']);
            if ($claimStatus === 'not_claimed') {
                $baseQuery->whereNull('reward_claims.id');
            } else {
                $baseQuery->where('reward_claims.status', $claimStatus);
            }
        }

        if (($queryParams['q'] ?? null) !== null && trim((string) $queryParams['q']) !== '') {
            $q = trim((string) $queryParams['q']);
            $baseQuery->where(function ($nested) use ($q): void {
                $nested->where('winning_tickets.id', 'like', '%'.$q.'%')
                    ->orWhere('winning_tickets.ticket_id', 'like', '%'.$q.'%')
                    ->orWhere('tickets.full_number', 'like', '%'.$q.'%')
                    ->orWhere('customers.customer_no', 'like', '%'.$q.'%')
                    ->orWhere('customers.name', 'like', '%'.$q.'%')
                    ->orWhere('customers.phone', 'like', '%'.$q.'%')
                    ->orWhere('reward_claims.reference', 'like', '%'.$q.'%');
            });
        }

        $winnerCount = (clone $baseQuery)->count('winning_tickets.id');
        $totalPrizeAmount = $this->sumWinnerQueryAmount(clone $baseQuery);

        if (($queryParams['cursor'] ?? null) !== null && trim((string) $queryParams['cursor']) !== '') {
            $baseQuery->where('winning_tickets.id', '>', trim((string) $queryParams['cursor']));
        }

        $rows = $baseQuery
            ->select([
                'winning_tickets.id',
                'winning_tickets.tenant_id',
                'winning_tickets.game_id',
                'winning_tickets.ticket_id',
                'winning_tickets.reward_result_id',
                'winning_tickets.reward_prize_id',
                'winning_tickets.prize_type',
                'winning_tickets.prize_number',
                'winning_tickets.amount',
                'winning_tickets.base_amount',
                'winning_tickets.adjustment_amount',
                'winning_tickets.tenant_price_rule_id',
                'winning_tickets.currency',
                'winning_tickets.status',
                'winning_tickets.created_at',
                'winning_tickets.updated_at',
                'tickets.full_number',
                'tickets.status as ticket_status',
                'customers.id as customer_id',
                'customers.customer_no',
                'customers.name as customer_name',
                'customers.first_name as customer_first_name',
                'customers.last_name as customer_last_name',
                'customers.phone as customer_phone',
                'partner_tenants.code as tenant_code',
                'partner_tenants.name as tenant_name',
                'reward_claims.id as claim_id',
                'reward_claims.reference as claim_reference',
                'reward_claims.status as claim_status',
                'reward_claims.payout_method as claim_payout_method',
                'reward_claims.submitted_at as claim_submitted_at',
                'reward_claims.paid_at as claim_paid_at',
            ])
            ->orderBy('winning_tickets.id')
            ->limit($limit + 1)
            ->get()
            ->all();

        $hasMore = count($rows) > $limit;
        $rows = array_slice($rows, 0, $limit);

        return [
            'data' => array_map(fn (object $winner): array => $this->centralWinnerResource($winner, $game), $rows),
            'meta' => [
                'game_id' => (string) $game->id,
                'default_game_id' => $defaultGameId,
                'game' => $this->winnerGameResource($game, $defaultGameId),
                'scope_type' => $tenantId === null ? 'central' : 'tenant',
                'tenant_id' => $tenantId,
                'has_live_result' => false,
                'completion_percent' => 0,
                'source' => ['name' => 'official'],
                'winner_count' => $winnerCount,
                'winning_row_count' => $winnerCount,
                'total_prize_amount' => $this->money($totalPrizeAmount),
                'prize_breakdown' => [],
                'official_claimable' => true,
                'realtime' => [
                    'event' => 'reward.result.live.updated',
                    'channels' => [
                        'public.results.latest',
                        'public.results.game.'.(string) $game->id,
                    ],
                ],
                'next_cursor' => $hasMore && $rows !== [] ? (string) end($rows)->id : null,
                'has_more' => $hasMore,
            ],
        ];
    }

    /**
     * @return array<string, mixed>
     */
    public function centralWinnerGames(): array
    {
        $defaultGameId = $this->defaultWinnerGameId();
        $rows = Game::query()
            ->where('status', '<>', 'archived')
            ->orderByDesc('draw_at')
            ->orderByDesc('sale_start_at')
            ->limit(100)
            ->get()
            ->all();

        return [
            'data' => array_map(fn (object $game): array => $this->winnerGameResource($game, $defaultGameId), $rows),
            'meta' => [
                'default_game_id' => $defaultGameId,
            ],
        ];
    }

    /**
     * @return array<string, mixed>
     */
    public function tenantWinnerGames(string $tenantId): array
    {
        $defaultGameId = $this->defaultWinnerGameId($tenantId);
        $rows = Game::query()
            ->where('status', '<>', 'archived')
            ->whereExists(function ($query) use ($tenantId): void {
                $query->select(DB::raw(1))
                    ->from('tickets')
                    ->whereColumn('tickets.game_id', 'games.id')
                    ->where('tickets.tenant_id', $tenantId);
            })
            ->orderByDesc('draw_at')
            ->orderByDesc('sale_start_at')
            ->limit(100)
            ->get()
            ->all();

        return [
            'data' => array_map(fn (object $game): array => $this->winnerGameResource($game, $defaultGameId), $rows),
            'meta' => [
                'default_game_id' => $defaultGameId,
                'scope_type' => 'tenant',
                'tenant_id' => $tenantId,
            ],
        ];
    }

    private function defaultWinnerGameId(?string $tenantId = null): ?string
    {
        $gameId = Game::query()
            ->whereNotNull('sale_start_at')
            ->where('sale_start_at', '<=', now())
            ->whereNotIn('status', ['draft', 'archived'])
            ->when($tenantId !== null, fn ($query) => $query->whereExists(function ($nested) use ($tenantId): void {
                $nested->select(DB::raw(1))
                    ->from('tickets')
                    ->whereColumn('tickets.game_id', 'games.id')
                    ->where('tickets.tenant_id', $tenantId);
            }))
            ->orderByDesc('sale_start_at')
            ->orderByDesc('draw_at')
            ->value('id');

        if ($gameId !== null) {
            return (string) $gameId;
        }

        $fallback = Game::query()
            ->where('status', '<>', 'archived')
            ->when($tenantId !== null, fn ($query) => $query->whereExists(function ($nested) use ($tenantId): void {
                $nested->select(DB::raw(1))
                    ->from('tickets')
                    ->whereColumn('tickets.game_id', 'games.id')
                    ->where('tickets.tenant_id', $tenantId);
            }))
            ->orderByDesc('draw_at')
            ->orderByDesc('sale_start_at')
            ->value('id');

        return $fallback === null ? null : (string) $fallback;
    }

    /**
     * @param array<string, mixed>|null $liveResult
     * @param array<string, mixed> $liveEstimate
     * @param array<string, mixed> $byPrizeType
     * @return array<string, mixed>
     */
    private function centralWinnerLiveMeta(
        object $game,
        ?string $defaultGameId,
        ?array $liveResult,
        array $liveEstimate,
        int $winningTicketCount,
        int $winningRowCount,
        array $byPrizeType,
        bool $hasLiveResult,
        int $totalPrizeAmount = 0,
        ?string $tenantId = null,
    ): array {
        $gameId = (string) $game->id;
        $scopedLiveEstimate = [
            ...$liveEstimate,
            'estimated_winning_ticket_count' => $winningTicketCount,
            'estimated_winning_rows' => $winningRowCount,
            'estimated_payout_amount' => $this->money($totalPrizeAmount),
            'by_prize_type' => $byPrizeType,
            'official_claimable' => false,
        ];

        if ($tenantId !== null && $liveResult !== null) {
            $liveResult['live_estimate'] = $scopedLiveEstimate;
        }

        return [
            'game_id' => $gameId,
            'default_game_id' => $defaultGameId,
            'game' => $this->winnerGameResource($game, $defaultGameId),
            'scope_type' => $tenantId === null ? 'central' : 'tenant',
            'tenant_id' => $tenantId,
            'reward_result_id' => $liveResult['reward_result_id'] ?? null,
            'live_result' => $liveResult,
            'has_live_result' => $hasLiveResult,
            'completion_percent' => (float) ($liveResult['completion_percent'] ?? 0),
            'source' => $liveResult['source'] ?? ['name' => 'sanook'],
            'winner_count' => $winningTicketCount,
            'winning_row_count' => $winningRowCount,
            'total_prize_amount' => $this->money($totalPrizeAmount),
            'prize_breakdown' => $byPrizeType,
            'live_estimate' => $scopedLiveEstimate,
            'official_claimable' => false,
            'updated_at' => $liveResult['updated_at'] ?? null,
            'realtime' => [
                'event' => 'reward.result.live.updated',
                'channels' => [
                    'public.results.latest',
                    'public.results.game.'.$gameId,
                ],
            ],
        ];
    }

    private function latestDraftWinnerPreviewResultForGame(string $gameId): ?object
    {
        return RewardResult::query()
            ->where('game_id', $gameId)
            ->where('status', 'draft')
            ->orderByDesc('updated_at')
            ->first();
    }

    /**
     * @return array{rows: array<int, array<string, mixed>>, winning_ticket_count: int, winning_row_count: int, total_prize_amount: int, by_prize_type: array<string, mixed>}
     */
    private function centralWinnerLiveRows(object $result, object $game, int $limit, ?string $tenantId = null): array
    {
        $prizes = $this->completedRewardPrizes((string) $result->id);
        $groups = [];
        $rows = [];
        $totalPrizeAmount = 0;
        $byPrizeType = [];
        $pricingCache = [];

        foreach ($prizes as $prize) {
            $matches = $this->ticketPrizeAggregateRows((string) $game->id, $prize, $tenantId)->get()->all();

            foreach ($matches as $match) {
                $ticketCount = (int) $match->ticket_count;
                if ($ticketCount < 1) {
                    continue;
                }

                $pricing = $this->livePricingForPrize((string) $match->tenant_id, (string) $game->id, $prize, $pricingCache);
                $amount = (int) $pricing['effective_amount'];
                $type = (string) $prize->prize_type;
                $currency = (string) ($pricing['currency'] ?? $prize->currency ?? 'THB');
                $totalAmount = $ticketCount * $amount;
                $fullNumber = (string) $match->full_number;
                $tenantId = (string) $match->tenant_id;
                $totalPrizeAmount += $totalAmount;
                $byPrizeType[$type] ??= [
                    'prize_type' => $type,
                    'winner_count' => 0,
                    'winning_row_count' => 0,
                    'total_prize_amount' => $this->money(0, $currency),
                ];
                $byPrizeType[$type]['winner_count'] += $ticketCount;
                $byPrizeType[$type]['winning_row_count'] += $ticketCount;
                $byPrizeType[$type]['total_prize_amount'] = $this->money(
                    (int) $byPrizeType[$type]['total_prize_amount']['amount'] + $totalAmount,
                    $currency,
                );

                $groups[$fullNumber] ??= $this->emptyLiveWinnerGroup($result, $game, $fullNumber, $currency);
                $this->addLiveWinnerGroupMatch($groups[$fullNumber], $match, $prize, $pricing, $ticketCount, $totalAmount);
            }
        }

        uasort($groups, fn (array $left, array $right): int => (
            ($right['total_prize_amount'] <=> $left['total_prize_amount'])
                ?: ($right['ticket_count'] <=> $left['ticket_count'])
                ?: strcmp((string) $left['full_number'], (string) $right['full_number'])
        ));

        foreach (array_slice($groups, 0, $limit) as $group) {
            $rows[] = $this->centralWinnerLiveGroupResource($group);
        }

        return [
            'rows' => $rows,
            'winning_ticket_count' => array_sum(array_map(
                fn (array $group): int => (int) $group['ticket_count'],
                $groups,
            )),
            'winning_row_count' => array_sum(array_map(
                fn (array $row): int => (int) $row['winning_row_count'],
                $byPrizeType,
            )),
            'total_prize_amount' => $totalPrizeAmount,
            'by_prize_type' => array_values($byPrizeType),
        ];
    }

    /**
     * @return array<int, object>
     */
    private function completedRewardPrizes(string $rewardResultId): array
    {
        return RewardPrize::query()
            ->where('reward_result_id', $rewardResultId)
            ->orderBy('sort_order')
            ->get()
            ->filter(fn (object $prize): bool => ! $this->isPendingPrizeNumber((string) $prize->prize_number))
            ->values()
            ->all();
    }

    private function ticketPrizeAggregateRows(string $gameId, object $prize, ?string $tenantId = null)
    {
        $query = DB::table('tickets')
            ->leftJoin('partner_tenants', 'partner_tenants.id', '=', 'tickets.tenant_id')
            ->leftJoin('customers', 'customers.id', '=', 'tickets.customer_id')
            ->where('tickets.game_id', $gameId)
            ->whereIn('tickets.status', ['active', 'reward_pending', 'winning', 'non_winning']);

        if ($tenantId !== null) {
            $query->where('tickets.tenant_id', $tenantId);
        }

        $this->applyTicketPrizeMatchConstraint($query, $prize);

        return $query
            ->select([
                'tickets.tenant_id',
                'tickets.game_id',
                'tickets.full_number',
                'partner_tenants.code as tenant_code',
                'partner_tenants.name as tenant_name',
                DB::raw('COUNT(*) as ticket_count'),
                DB::raw('COUNT(DISTINCT tickets.customer_id) as customer_count'),
                DB::raw('MIN(tickets.id) as sample_ticket_id'),
                DB::raw('MIN(customers.id) as customer_id'),
                DB::raw('MIN(customers.customer_no) as customer_no'),
                DB::raw('MIN(customers.name) as customer_name'),
                DB::raw('MIN(customers.first_name) as customer_first_name'),
                DB::raw('MIN(customers.last_name) as customer_last_name'),
                DB::raw('MIN(customers.phone) as customer_phone'),
                DB::raw('MAX(tickets.updated_at) as updated_at'),
            ])
            ->groupBy([
                'tickets.tenant_id',
                'tickets.game_id',
                'tickets.full_number',
                'partner_tenants.code',
                'partner_tenants.name',
            ])
            ->orderBy('tickets.full_number')
            ->orderBy('tickets.tenant_id');
    }

    private function applyTicketPrizeMatchConstraint($query, object $prize): void
    {
        $type = strtolower((string) $prize->prize_type);
        $number = (string) $prize->prize_number;

        if (str_contains($type, 'front3')) {
            $query->where('tickets.full_number', 'like', $number.'%');

            return;
        }

        if (str_contains($type, 'back3') || str_contains($type, 'back2')) {
            $query->where('tickets.full_number', 'like', '%'.$number);

            return;
        }

        $query->where('tickets.full_number', $number);
    }

    /**
     * @param array<string, array<string, mixed>> $cache
     * @return array<string, mixed>
     */
    private function livePricingForPrize(string $tenantId, string $gameId, object $prize, array &$cache): array
    {
        $key = $tenantId.':'.$gameId.':'.(string) $prize->id;
        $cache[$key] ??= $this->tenantRewardPriceRules->resolveForPrize($tenantId, $gameId, $prize);

        return $cache[$key];
    }

    /**
     * @return array<string, mixed>
     */
    private function emptyLiveWinnerGroup(object $result, object $game, string $fullNumber, string $currency): array
    {
        return [
            'id' => 'winner_group_'.substr(sha1($result->id.':'.$fullNumber), 0, 20),
            'game_id' => (string) $game->id,
            'game_code' => (string) $game->code,
            'game_name' => (string) $game->name,
            'game' => $this->winnerGameResource($game),
            'reward_result_id' => (string) $result->id,
            'full_number' => $fullNumber,
            'ticket_count' => 0,
            'total_prize_amount' => 0,
            'currency' => $currency,
            'status' => match ((string) $result->status) {
                'draft' => 'live_draft',
                'published' => 'published',
                default => 'live_unconfirmed',
            },
            'source' => $this->rewardResultPreviewSourceName($result),
            'official_claimable' => false,
            'created_at' => $result->updated_at,
            'updated_at' => $result->updated_at,
            '_ticket_counts' => [],
            '_tenants' => [],
            '_customers' => [],
            '_customer_counts' => [],
            '_prize_breakdown' => [],
        ];
    }

    private function rewardResultPreviewSourceName(object $result): string
    {
        $summary = $this->decodeJsonObject($result->summary_json);
        $source = trim((string) ($summary['source']['name'] ?? ''));

        return $source !== '' ? $source : 'central';
    }

    /**
     * @param array<string, mixed> $group
     * @param array<string, mixed> $pricing
     */
    private function addLiveWinnerGroupMatch(array &$group, object $match, object $prize, array $pricing, int $ticketCount, int $totalAmount): void
    {
        $tenantId = (string) $match->tenant_id;
        $type = (string) $prize->prize_type;
        $currency = (string) ($pricing['currency'] ?? $group['currency'] ?? 'THB');
        $group['currency'] = $currency;
        $group['total_prize_amount'] = (int) $group['total_prize_amount'] + $totalAmount;
        $group['updated_at'] = $match->updated_at ?? $group['updated_at'];
        $group['_ticket_counts'][$tenantId] = max((int) ($group['_ticket_counts'][$tenantId] ?? 0), $ticketCount);
        $group['ticket_count'] = array_sum($group['_ticket_counts']);
        $group['_tenants'][$tenantId] ??= [
            'id' => $tenantId,
            'code' => $match->tenant_code,
            'name' => $match->tenant_name,
            'ticket_count' => 0,
        ];
        $group['_tenants'][$tenantId]['ticket_count'] = max((int) $group['_tenants'][$tenantId]['ticket_count'], $ticketCount);
        $customerId = $match->customer_id === null ? null : (string) $match->customer_id;
        if ($customerId !== null && $customerId !== '') {
            $customerNo = CustomerNo::display($match->customer_no ?? null, $customerId);
            $customerName = $this->winnerCustomerName($match, $customerNo);
            $group['_customers'][$customerId] ??= [
                'id' => $customerId,
                'customer_no' => $customerNo,
                'name' => $customerName,
                'phone' => $match->customer_phone,
                'ticket_count' => 0,
            ];
            $group['_customers'][$customerId]['ticket_count'] = max((int) $group['_customers'][$customerId]['ticket_count'], $ticketCount);
        }
        $group['_customer_counts'][$tenantId] = max(
            (int) ($group['_customer_counts'][$tenantId] ?? 0),
            (int) ($match->customer_count ?? ($customerId === null ? 0 : 1)),
        );
        $group['_prize_breakdown'][$type] ??= [
            'prize_type' => $type,
            'prize_numbers' => [],
            'ticket_count' => 0,
            'winner_count' => 0,
            'winning_row_count' => 0,
            'total_prize_amount' => 0,
            'currency' => $currency,
        ];
        $group['_prize_breakdown'][$type]['prize_numbers'][(string) $prize->prize_number] = true;
        $group['_prize_breakdown'][$type]['ticket_count'] += $ticketCount;
        $group['_prize_breakdown'][$type]['winner_count'] += $ticketCount;
        $group['_prize_breakdown'][$type]['winning_row_count'] += $ticketCount;
        $group['_prize_breakdown'][$type]['total_prize_amount'] += $totalAmount;
    }

    /**
     * @param array<string, mixed> $group
     * @return array<string, mixed>
     */
    private function centralWinnerLiveGroupResource(array $group): array
    {
        $breakdown = array_values(array_map(function (array $row): array {
            $currency = (string) ($row['currency'] ?? 'THB');

            return [
                'prize_type' => $row['prize_type'],
                'prize_numbers' => array_keys($row['prize_numbers']),
                'ticket_count' => (int) $row['ticket_count'],
                'winner_count' => (int) $row['winner_count'],
                'winning_row_count' => (int) $row['winning_row_count'],
                'total_prize_amount' => $this->money((int) $row['total_prize_amount'], $currency),
            ];
        }, $group['_prize_breakdown']));
        $prizeTypes = array_values(array_map(fn (array $row): string => (string) $row['prize_type'], $breakdown));
        $prizeNumbers = array_values(array_unique(array_merge(...array_map(
            fn (array $row): array => $row['prize_numbers'],
            $breakdown,
        ))));
        $tenants = array_values($group['_tenants']);
        $customers = array_values($group['_customers']);
        $customerCount = max(count($customers), array_sum(array_map('intval', $group['_customer_counts'])));
        $totalPrizeAmount = $this->money((int) $group['total_prize_amount'], (string) $group['currency']);

        return [
            'id' => (string) $group['id'],
            'game_id' => (string) $group['game_id'],
            'game_code' => (string) $group['game_code'],
            'game_name' => (string) $group['game_name'],
            'game' => $group['game'],
            'reward_result_id' => (string) $group['reward_result_id'],
            'full_number' => (string) $group['full_number'],
            'ticket_count' => (int) $group['ticket_count'],
            'prize_type' => count($prizeTypes) === 1 ? $prizeTypes[0] : 'multiple',
            'prize_types' => $prizeTypes,
            'prize_number' => count($prizeNumbers) === 1 ? $prizeNumbers[0] : null,
            'prize_numbers' => $prizeNumbers,
            'prize_breakdown' => $breakdown,
            'total_prize_amount' => $totalPrizeAmount,
            'prize_amount' => $totalPrizeAmount,
            'tenant_count' => count($tenants),
            'tenant_code' => $this->liveTenantSummary($tenants, 'code'),
            'tenant_name' => $this->liveTenantSummary($tenants, 'name'),
            'tenants' => $tenants,
            'customer_count' => $customerCount,
            'ticket_id' => null,
            'ticket_status' => null,
            'customer_id' => $customerCount === 1 && count($customers) === 1 ? (string) $customers[0]['id'] : null,
            'customer_no' => $this->liveCustomerSummary($customers, 'customer_no'),
            'customer_name' => $customerCount === 1 && count($customers) === 1 ? $customers[0]['name'] : null,
            'customer_phone' => $customerCount === 1 && count($customers) === 1 ? $customers[0]['phone'] : null,
            'customers' => $customers,
            'claim_id' => null,
            'claim_reference' => null,
            'claim_status' => 'pending_confirmation',
            'claim_payout_method' => null,
            'claim_submitted_at' => null,
            'claim_paid_at' => null,
            'status' => (string) $group['status'],
            'source' => (string) $group['source'],
            'official_claimable' => (bool) $group['official_claimable'],
            'created_at' => $group['created_at'],
            'updated_at' => $group['updated_at'],
        ];
    }

    /**
     * @param array<int, array<string, mixed>> $tenants
     */
    private function liveTenantSummary(array $tenants, string $field): ?string
    {
        $values = array_values(array_filter(array_map(
            fn (array $tenant): string => trim((string) ($tenant[$field] ?? '')),
            $tenants,
        )));

        if ($values === []) {
            return null;
        }

        $visible = array_slice($values, 0, 2);
        $suffix = count($values) > 2 ? ' +'.(count($values) - 2).' more' : '';

        return implode(', ', $visible).$suffix;
    }

    /**
     * @param array<int, array<string, mixed>> $customers
     */
    private function liveCustomerSummary(array $customers, string $field): ?string
    {
        return $this->liveTenantSummary($customers, $field);
    }

    /**
     * @return array<string, mixed>
     */
    private function winnerGameResource(object $game, ?string $defaultGameId = null): array
    {
        return [
            'id' => (string) $game->id,
            'game_id' => (string) $game->id,
            'code' => (string) $game->code,
            'name' => (string) $game->name,
            'status' => (string) $game->status,
            'sale_start_at' => $game->sale_start_at,
            'draw_at' => $game->draw_at,
            'close_at' => $game->close_at,
            'is_default' => $defaultGameId !== null && (string) $game->id === $defaultGameId,
        ];
    }

    /**
     * @return array<string, mixed>
     */
    private function centralWinnerResource(object $winner, object $game): array
    {
        $customerId = $winner->customer_id === null ? null : (string) $winner->customer_id;
        $customerNo = $customerId === null ? null : CustomerNo::display($winner->customer_no ?? null, $customerId);
        $customerName = $this->winnerCustomerName($winner, $customerNo);
        $claimId = $winner->claim_id === null ? null : (string) $winner->claim_id;

        return [
            'id' => (string) $winner->id,
            'tenant_id' => (string) $winner->tenant_id,
            'tenant_code' => $winner->tenant_code,
            'tenant_name' => $winner->tenant_name,
            'tenant' => [
                'id' => (string) $winner->tenant_id,
                'code' => $winner->tenant_code,
                'name' => $winner->tenant_name,
            ],
            'game_id' => (string) $winner->game_id,
            'game_code' => (string) $game->code,
            'game_name' => (string) $game->name,
            'game' => $this->winnerGameResource($game),
            'ticket_id' => (string) $winner->ticket_id,
            'full_number' => $winner->full_number,
            'ticket_status' => $winner->ticket_status,
            'ticket' => [
                'id' => (string) $winner->ticket_id,
                'full_number' => $winner->full_number,
                'status' => $winner->ticket_status,
            ],
            'customer_id' => $customerId,
            'customer_no' => $customerNo,
            'customer_name' => $customerName,
            'customer_phone' => $winner->customer_phone,
            'customer_count' => $customerId === null ? 0 : 1,
            'customer' => $customerId === null ? null : [
                'id' => $customerId,
                'customer_no' => $customerNo,
                'name' => $customerName,
                'phone' => $winner->customer_phone,
            ],
            'reward_result_id' => (string) $winner->reward_result_id,
            'reward_prize_id' => (string) $winner->reward_prize_id,
            'prize_type' => (string) $winner->prize_type,
            'prize_types' => [(string) $winner->prize_type],
            'prize_number' => (string) $winner->prize_number,
            'prize_numbers' => [(string) $winner->prize_number],
            'prize_amount' => $this->money($this->normalizedWinningAmount($winner, 'amount'), (string) $winner->currency),
            'total_prize_amount' => $this->money($this->normalizedWinningAmount($winner, 'amount'), (string) $winner->currency),
            'ticket_count' => 1,
            'tenant_count' => 1,
            'tenant_summary' => $winner->tenant_name ?? $winner->tenant_code,
            'prize_breakdown' => [[
                'prize_type' => (string) $winner->prize_type,
                'prize_numbers' => [(string) $winner->prize_number],
                'ticket_count' => 1,
                'winner_count' => 1,
                'winning_row_count' => 1,
                'total_prize_amount' => $this->money($this->normalizedWinningAmount($winner, 'amount'), (string) $winner->currency),
            ]],
            'base_amount' => $this->money($this->normalizedWinningAmount($winner, 'base_amount', 'amount'), (string) $winner->currency),
            'adjustment_amount' => $this->money((int) ($winner->adjustment_amount ?? 0), (string) $winner->currency),
            'tenant_price_rule_id' => $winner->tenant_price_rule_id,
            'claim_id' => $claimId,
            'claim_reference' => $winner->claim_reference,
            'claim_status' => $winner->claim_status ?? 'not_claimed',
            'claim_payout_method' => $winner->claim_payout_method,
            'claim_submitted_at' => $winner->claim_submitted_at,
            'claim_paid_at' => $winner->claim_paid_at,
            'status' => (string) $winner->status,
            'created_at' => $winner->created_at,
            'updated_at' => $winner->updated_at,
        ];
    }

    private function sumWinnerQueryAmount(mixed $query): int
    {
        return (int) $query
            ->select([
                'winning_tickets.prize_type',
                'winning_tickets.amount',
                'winning_tickets.currency',
                'winning_tickets.tenant_price_rule_id',
                DB::raw('COUNT(*) as row_count'),
            ])
            ->groupBy([
                'winning_tickets.prize_type',
                'winning_tickets.amount',
                'winning_tickets.currency',
                'winning_tickets.tenant_price_rule_id',
            ])
            ->get()
            ->reduce(
                fn (int $total, object $row): int => $total + ($this->normalizedWinningAmount($row, 'amount') * (int) $row->row_count),
                0,
            );
    }

    private function winnerCustomerName(object $winner, ?string $fallback): ?string
    {
        $name = trim((string) ($winner->customer_name ?? ''));

        if ($name !== '') {
            return $name;
        }

        $firstLast = trim(trim((string) ($winner->customer_first_name ?? '')).' '.trim((string) ($winner->customer_last_name ?? '')));

        return $firstLast === '' ? $fallback : $firstLast;
    }

    /**
     * @return array<string, mixed>
     */
    public function centralLiveSettings(): array
    {
        $url = $this->centralWaitingResultYoutubeUrl();

        return [
            'id' => 'central_reward_live_settings',
            'waiting_result_youtube_url' => $url,
            'waiting_result_youtube_embed_url' => YoutubeLiveUrl::embedUrl($url),
            'source' => $url !== '' ? 'central_default' : 'not_configured',
            'updated_at' => PlatformSystemSetting::query()
                ->where('key', 'waiting_result_youtube_url')
                ->value('updated_at'),
        ];
    }

    /**
     * @param array<string, mixed> $payload
     * @return array<string, array<int, string>>
     */
    public function validateCentralLiveSettingsPayload(array $payload): array
    {
        $value = $this->liveSettingsPayloadValue($payload);

        if ($value === null) {
            return [
                'waiting_result_youtube_url' => ['The waiting_result_youtube_url field is required.'],
            ];
        }

        if (! YoutubeLiveUrl::isAllowedOrEmpty($value)) {
            return [
                'waiting_result_youtube_url' => ['The waiting_result_youtube_url field must be a valid YouTube URL.'],
            ];
        }

        return [];
    }

    /**
     * @param array<string, mixed> $payload
     * @return array{resource: array<string, mixed>}
     */
    public function updateCentralLiveSettings(array $payload, AdminSessionContext $actor, Request $request): array
    {
        $url = trim((string) ($this->liveSettingsPayloadValue($payload) ?? ''));
        $normalized = ['waiting_result_youtube_url' => $url];
        $idempotencyKey = (string) $request->header('Idempotency-Key');

        return DB::transaction(function () use ($actor, $idempotencyKey, $normalized, $request, $url): array {
            $replay = $this->idempotency->replayOrConflict(null, 'central_admin', $actor->adminUser['id'], 'admin.central.rewards.live-settings.patch', $idempotencyKey, $normalized, 'reward.create', true);

            if (is_array($replay)) {
                return ['resource' => $replay['body'] ?? [], 'status' => $replay['status']];
            }

            if ($replay === 'idempotency_conflict' || $replay === 'resource_conflict') {
                return ['error' => $replay];
            }

            $setting = PlatformSystemSetting::query()->firstOrNew(['key' => 'waiting_result_youtube_url']);

            if (! $setting->exists) {
                $setting->id = 'pss_'.substr(sha1('waiting_result_youtube_url'), 0, 20);
                $setting->key = 'waiting_result_youtube_url';
            }

            $setting->fill([
                'value_json' => $url,
                'status' => 'active',
            ]);
            $setting->save();

            $this->auditAdmin($actor, $request, 'reward.live_settings.updated', 'platform_system_setting', 'waiting_result_youtube_url', $normalized);

            $resource = $this->centralLiveSettings();
            $this->idempotency->storeResponse(null, 'central_admin', $actor->adminUser['id'], 'admin.central.rewards.live-settings.patch', $idempotencyKey, $normalized, 200, $resource, 'reward.create');

            return ['resource' => $resource];
        });
    }

    /**
     * @param array<string, mixed> $payload
     * @return array<string, array<int, string>>
     */
    public function validateLiveIngestPayload(array $payload): array
    {
        $errors = [];
        $rules = ThaiGovernmentLotteryRewardTemplate::rules();
        $source = trim((string) ($payload['source'] ?? ''));
        $drawCode = trim((string) ($payload['draw_code'] ?? ''));
        $payloadHash = trim((string) ($payload['payload_hash'] ?? ''));
        $prizes = $payload['prizes'] ?? null;

        if ($source !== 'sanook') {
            $errors['source'][] = 'The source field must be sanook.';
        }

        if (! preg_match('/^[0-9]{8}$/', $drawCode)) {
            $errors['draw_code'][] = 'The draw_code field must contain exactly 8 digits.';
        }

        if ($payloadHash === '' || strlen($payloadHash) > 128) {
            $errors['payload_hash'][] = 'The payload_hash field is required and must not exceed 128 characters.';
        }

        if (! is_array($prizes) || $prizes === []) {
            $errors['prizes'][] = 'The prizes field must contain at least one prize group.';

            return $errors;
        }

        $seenByType = [];

        foreach (array_values($prizes) as $index => $prize) {
            $row = is_array($prize) ? $prize : [];
            $type = trim((string) ($row['prize_type'] ?? ''));
            $numbers = $row['prize_numbers'] ?? null;
            $rule = $rules[$type] ?? null;

            if ($type === '' || $rule === null) {
                $errors["prizes.$index.prize_type"][] = 'The prize_type field must be a Thai Government Lottery prize type.';
                continue;
            }

            if (! is_array($numbers) || $numbers === []) {
                $errors["prizes.$index.prize_numbers"][] = 'The prize_numbers field must contain at least one number.';
                continue;
            }

            if (count($numbers) > $rule['count']) {
                $errors["prizes.$index.prize_numbers"][] = 'The '.$type.' prize_numbers field cannot contain more than '.$rule['count'].' number(s).';
            }

            foreach (array_values($numbers) as $numberIndex => $number) {
                $normalizedNumber = trim((string) $number);
                $isPending = preg_match('/^x{'.$rule['digits'].'}$/i', $normalizedNumber) === 1;

                if (! $isPending && ! preg_match('/^[0-9]{'.$rule['digits'].'}$/', $normalizedNumber)) {
                    $errors["prizes.$index.prize_numbers.$numberIndex"][] = 'The '.$type.' prize number must contain exactly '.$rule['digits'].' digits or x placeholders.';
                    continue;
                }

                if ($isPending) {
                    continue;
                }

                $seenKey = $type.':'.$normalizedNumber;
                if (isset($seenByType[$seenKey])) {
                    $errors["prizes.$index.prize_numbers.$numberIndex"][] = 'Duplicate live prize numbers are not allowed in the same prize group.';
                }
                $seenByType[$seenKey] = true;
            }
        }

        return $errors;
    }

    /**
     * @param array<string, mixed> $payload
     * @return array{resource?: array<string, mixed>, error?: string}
     */
    public function ingestSanookLiveResult(array $payload, Request $request): array
    {
        $normalized = $this->normalizeLiveIngestPayload($payload);

        return DB::transaction(function () use ($normalized, $request): array {
            $game = Game::query()
                ->where('code', $normalized['draw_code'])
                ->lockForUpdate()
                ->first();

            if ($game === null) {
                return ['error' => 'not_found'];
            }

            $result = RewardResult::query()
                ->where('game_id', $game->id)
                ->lockForUpdate()
                ->first();

            if ($result === null) {
                $result = $this->createDraftRewardResultForGame((string) $game->id);
            }

            if ((string) $result->status !== 'draft') {
                return ['error' => 'resource_conflict'];
            }

            $previousSummary = $this->decodeJsonObject($result->summary_json);
            if (($previousSummary['source']['payload_hash'] ?? null) === $normalized['payload_hash']) {
                return ['resource' => $this->publicLiveSummary($result) + ['changed' => false]];
            }

            $this->ensureDraftRewardPrizes((string) $result->id, (string) $game->id);
            $this->applyLivePrizeUpdates((string) $result->id, $normalized['prizes']);

            $summary = [
                'source' => [
                    'name' => 'sanook',
                    'draw_code' => $normalized['draw_code'],
                    'draw_date' => $normalized['draw_date'],
                    'scraped_at' => $normalized['scraped_at'],
                    'payload_hash' => $normalized['payload_hash'],
                    'request_id' => $request->header('X-Request-Id'),
                ],
                'live' => [
                    'status' => 'draft',
                    'completion_percent' => $normalized['completion_percent'],
                    'updated_at' => now()->toISOString(),
                ],
                'live_estimate' => $this->liveWinnerEstimateSummary((string) $result->id, (string) $game->id),
            ];

            RewardResult::query()->where('id', $result->id)->update([
                'summary_json' => json_encode($summary, JSON_THROW_ON_ERROR),
                'updated_at' => now(),
            ]);

            $fresh = RewardResult::query()->where('id', $result->id)->first() ?? $result;
            $resource = $this->publicLiveSummary($fresh);
            RewardLiveResultUpdated::dispatch($this->compactLiveBroadcastPayload($resource) + [
                'event_type' => 'reward.result.live.updated',
                'changed' => true,
            ]);

            return ['resource' => $resource + ['changed' => true]];
        });
    }

    /**
     * @return array{body: array<string, mixed>|null, etag: string|null}
     */
    public function publicLiveLatestResult(): array
    {
        $result = RewardResult::query()
            ->join('games', 'games.id', '=', 'reward_results.game_id')
            ->whereIn('reward_results.status', self::PUBLIC_LIVE_RESULT_STATUSES)
            ->select('reward_results.*')
            ->orderByDesc('games.draw_at')
            ->orderByDesc('reward_results.updated_at')
            ->first();

        return $this->publicLiveResultEnvelope($result);
    }

    /**
     * @return array{body: array<string, mixed>|null, etag: string|null}
     */
    public function publicLiveResultForGame(string $gameId): array
    {
        $result = RewardResult::query()
            ->join('games', 'games.id', '=', 'reward_results.game_id')
            ->where('reward_results.game_id', $gameId)
            ->whereIn('reward_results.status', self::PUBLIC_LIVE_RESULT_STATUSES)
            ->select('reward_results.*')
            ->orderByDesc('reward_results.updated_at')
            ->first();

        return $this->publicLiveResultEnvelope($result);
    }

    /**
     * @return array<string, mixed>|null
     */
    public function rewardResult(string $rewardResultId): ?array
    {
        $result = RewardResult::find($rewardResultId);

        return $result === null ? null : $this->rewardResultResource($result);
    }

    /**
     * @param array<string, mixed> $payload
     * @return array{resource?: array<string, mixed>, status?: int, error?: string}
     */
    public function createRewardResult(array $payload, AdminSessionContext $actor, Request $request): array
    {
        $normalized = $this->normalizeRewardPayload($payload);
        $idempotencyKey = (string) $request->header('Idempotency-Key');

        return DB::transaction(function () use ($normalized, $actor, $request, $idempotencyKey): array {
            $replay = $this->idempotency->replayOrConflict(null, 'central_admin', $actor->adminUser['id'], 'admin.central.rewards.store', $idempotencyKey, $normalized, 'reward.create', true);

            if (is_array($replay)) {
                return ['resource' => $replay['body'] ?? [], 'status' => $replay['status']];
            }

            if ($replay !== null) {
                return ['error' => $replay];
            }

            $existingResult = RewardResult::query()
                ->where('game_id', $normalized['game_id'])
                ->lockForUpdate()
                ->first();

            if ($existingResult !== null && (string) $existingResult->status !== 'draft') {
                return ['error' => 'resource_conflict'];
            }

            $resultId = $existingResult === null ? 'rew_'.Str::ulid()->toBase32() : (string) $existingResult->id;
            $now = now();

            if ($existingResult === null) {
                RewardResult::query()->insert([
                    'id' => $resultId,
                    'game_id' => $normalized['game_id'],
                    'status' => 'recorded',
                    'version' => 1,
                    'summary_json' => null,
                    'created_by_admin_id' => $actor->adminUser['id'],
                    'created_at' => $now,
                    'updated_at' => $now,
                ]);
            } else {
                RewardResult::query()->where('id', $resultId)->update([
                    'status' => 'recorded',
                    'summary_json' => null,
                    'checked_at' => null,
                    'verified_at' => null,
                    'published_at' => null,
                    'corrected_at' => null,
                    'updated_at' => $now,
                ]);
            }

            $this->replacePrizes($resultId, $normalized['game_id'], $normalized['prizes']);
            $this->setGameStatus($normalized['game_id'], 'reward_recorded');
            $this->auditAdmin($actor, $request, 'reward.recorded', 'reward_result', $resultId, $normalized);
            $this->processRewardCheck($resultId, self::CHECK_CHUNK_SIZE, $idempotencyKey);
            $this->broadcastRewardLiveUpdate($resultId);

            $resource = $this->rewardResult($resultId) ?? [];
            $this->idempotency->storeResponse(null, 'central_admin', $actor->adminUser['id'], 'admin.central.rewards.store', $idempotencyKey, $normalized, 202, $resource, 'reward.create');

            return ['resource' => $resource, 'status' => 202];
        });
    }

    /**
     * @param array<string, mixed> $payload
     * @return array{resource?: array<string, mixed>, status?: int, error?: string}
     */
    public function updateRewardResult(string $rewardResultId, array $payload, AdminSessionContext $actor, Request $request): array
    {
        $normalized = $this->normalizeRewardPayload($payload, false);
        $idempotencyKey = (string) $request->header('Idempotency-Key');

        return DB::transaction(function () use ($rewardResultId, $normalized, $actor, $request, $idempotencyKey): array {
            $routeKey = 'admin.central.rewards.update:'.$rewardResultId;
            $replay = $this->idempotency->replayOrConflict(null, 'central_admin', $actor->adminUser['id'], $routeKey, $idempotencyKey, $normalized, 'reward.create', true);

            if (is_array($replay)) {
                return ['resource' => $replay['body'] ?? [], 'status' => $replay['status']];
            }

            if ($replay !== null) {
                return ['error' => $replay];
            }

            $result = RewardResult::query()->where('id', $rewardResultId)->lockForUpdate()->first();

            if ($result === null) {
                return ['error' => 'not_found'];
            }

            if (in_array((string) $result->status, ['published', 'corrected', 'archived'], true)) {
                return ['error' => 'resource_conflict'];
            }

            WinningTicket::query()->where('reward_result_id', $rewardResultId)->delete();
            RewardCheckItem::query()->where('reward_result_id', $rewardResultId)->delete();
            RewardCheckBatch::query()->where('reward_result_id', $rewardResultId)->delete();

            if (isset($normalized['prizes'])) {
                $this->replacePrizes($rewardResultId, (string) $result->game_id, $normalized['prizes']);
            }

            if (isset($normalized['prize_number_updates']) || isset($normalized['payout_amount_updates'])) {
                $this->applyPartialRewardUpdates($rewardResultId, $normalized);
            }

            $isComplete = $this->rewardPrizesAreComplete($rewardResultId);
            $nextStatus = $isComplete ? 'recorded' : 'draft';

            RewardResult::query()->where('id', $rewardResultId)->update([
                'status' => $nextStatus,
                'summary_json' => null,
                'checked_at' => null,
                'updated_at' => now(),
            ]);

            if ($isComplete) {
                $this->processRewardCheck($rewardResultId, self::CHECK_CHUNK_SIZE, $idempotencyKey);
            }
            $this->broadcastRewardLiveUpdate($rewardResultId);

            $this->auditAdmin($actor, $request, 'reward.updated', 'reward_result', $rewardResultId, $normalized);

            $resource = $this->rewardResult($rewardResultId) ?? [];
            $this->idempotency->storeResponse(null, 'central_admin', $actor->adminUser['id'], $routeKey, $idempotencyKey, $normalized, 200, $resource, 'reward.create');

            return ['resource' => $resource, 'status' => 200];
        });
    }

    /**
     * @return array<string, mixed>
     */
    public function checkBatches(string $rewardResultId): array
    {
        $rows = RewardCheckBatch::query()
            ->where('reward_result_id', $rewardResultId)
            ->orderBy('created_at')
            ->get()
            ->all();

        return [
            'data' => array_map(fn (object $batch): array => [
                'id' => (string) $batch->id,
                'reward_result_id' => (string) $batch->reward_result_id,
                'game_id' => (string) $batch->game_id,
                'status' => (string) $batch->status,
                'chunk_count' => (int) $batch->chunk_count,
                'processed_ticket_count' => (int) $batch->processed_ticket_count,
                'winning_count' => (int) $batch->winning_count,
                'started_at' => $batch->started_at,
                'completed_at' => $batch->completed_at,
            ], $rows),
            'meta' => ['next_cursor' => null, 'has_more' => false],
        ];
    }

    public function processRewardCheck(?string $rewardResultId = null, int $chunkSize = self::CHECK_CHUNK_SIZE, ?string $idempotencyKey = null): int
    {
        $query = RewardResult::query()
            ->whereIn('status', ['recorded', 'checking']);

        if ($rewardResultId !== null) {
            $query->where('id', $rewardResultId);
        }

        $results = $query->orderBy('id')->get()->all();
        $processed = 0;

        foreach ($results as $result) {
            $processed += $this->processSingleRewardCheck($result, max(1, $chunkSize), $idempotencyKey);
        }

        return $processed;
    }

    /**
     * @param array<string, mixed> $payload
     * @return array{resource?: array<string, mixed>, status?: int, error?: string}
     */
    public function verifyRewardResult(string $rewardResultId, array $payload, AdminSessionContext $actor, Request $request): array
    {
        return $this->centralWrite($rewardResultId, $payload, $actor, $request, 'admin.central.rewards.verify', 'reward.verify', function (object $result) use ($rewardResultId, $actor): array|string {
            if (! in_array((string) $result->status, ['summary_ready', 'verified'], true)) {
                return 'resource_conflict';
            }

            if (! RewardCheckBatch::where('reward_result_id', $rewardResultId)->where('status', 'completed')->exists()) {
                return 'resource_conflict';
            }

            RewardResult::query()->where('id', $rewardResultId)->update([
                'status' => 'verified',
                'verified_by_admin_id' => $actor->adminUser['id'],
                'verified_at' => now(),
                'updated_at' => now(),
            ]);
            WinningTicket::query()->where('reward_result_id', $rewardResultId)->where('status', 'pending')->update(['status' => 'verified', 'updated_at' => now()]);
            $this->setGameStatus((string) $result->game_id, 'reward_verified');
            $this->broadcastRewardLiveUpdate($rewardResultId);

            return $this->rewardResult($rewardResultId) ?? [];
        }, 'reward.verified');
    }

    /**
     * @param array<string, mixed> $payload
     * @return array{resource?: array<string, mixed>, status?: int, error?: string}
     */
    public function publishRewardResult(string $rewardResultId, array $payload, AdminSessionContext $actor, Request $request): array
    {
        return $this->centralWrite($rewardResultId, $payload, $actor, $request, 'admin.central.rewards.publish', 'reward.publish', function (object $result) use ($rewardResultId, $actor, $request): array|string {
            if ((string) $result->status === 'published') {
                return $this->rewardResult($rewardResultId) ?? [];
            }

            if ((string) $result->status !== 'verified') {
                return 'resource_conflict';
            }

            return $this->publishCheckedRewardResult($rewardResultId, $result, $actor, $request);
        }, 'reward.published');
    }

    /**
     * @param array<string, mixed> $payload
     * @return array{resource?: array<string, mixed>, status?: int, error?: string}
     */
    public function confirmLiveDraftResult(string $rewardResultId, array $payload, AdminSessionContext $actor, Request $request): array
    {
        return $this->centralWrite($rewardResultId, $payload, $actor, $request, 'admin.central.rewards.confirm_live', 'reward.create', function (object $result) use ($rewardResultId, $actor, $request): array|string {
            if ((string) $result->status === 'published') {
                return $this->rewardResult($rewardResultId) ?? [];
            }

            if (! in_array((string) $result->status, ['draft', 'recorded', 'checking', 'summary_ready', 'verified'], true)) {
                return 'resource_conflict';
            }

            if (! $this->rewardPrizesAreComplete($rewardResultId)) {
                return 'resource_conflict';
            }

            if (! in_array((string) $result->status, ['summary_ready', 'verified'], true)) {
                RewardResult::query()->where('id', $rewardResultId)->update([
                    'status' => 'recorded',
                    'checked_at' => null,
                    'verified_at' => null,
                    'published_at' => null,
                    'updated_at' => now(),
                ]);
                $this->setGameStatus((string) $result->game_id, 'reward_recorded');
                $this->processRewardCheck($rewardResultId, self::CHECK_CHUNK_SIZE, $request->header('Idempotency-Key'));
            }

            $fresh = RewardResult::query()->where('id', $rewardResultId)->first() ?? $result;

            return $this->publishCheckedRewardResult($rewardResultId, $fresh, $actor, $request);
        }, 'reward.live_confirmed', 202);
    }

    /**
     * @param array<string, mixed> $payload
     * @return array{resource?: array<string, mixed>, status?: int, error?: string}
     */
    public function redrawRewardResult(string $rewardResultId, array $payload, AdminSessionContext $actor, Request $request): array
    {
        return $this->centralWrite($rewardResultId, $payload, $actor, $request, 'admin.central.rewards.redraw', 'reward.create', function (object $result) use ($rewardResultId, $actor, $payload): array|string {
            if (! in_array((string) $result->status, ['published', 'verified', 'summary_ready'], true)) {
                return 'resource_conflict';
            }

            $winningTicketIds = WinningTicket::query()
                ->where('reward_result_id', $rewardResultId)
                ->pluck('id')
                ->all();

            if ($winningTicketIds !== []) {
                $approvedClaimExists = RewardClaim::query()
                    ->whereIn('winning_ticket_id', $winningTicketIds)
                    ->whereIn('status', ['approved', 'paid'])
                    ->exists();

                if ($approvedClaimExists) {
                    return 'resource_conflict';
                }

                RewardClaim::query()
                    ->whereIn('winning_ticket_id', $winningTicketIds)
                    ->delete();
            }

            WinningTicket::query()->where('reward_result_id', $rewardResultId)->delete();
            RewardCheckItem::query()->where('reward_result_id', $rewardResultId)->delete();
            RewardCheckBatch::query()->where('reward_result_id', $rewardResultId)->delete();
            RewardPrize::query()->where('reward_result_id', $rewardResultId)->delete();
            $this->ensureDraftRewardPrizes($rewardResultId, (string) $result->game_id);

            RewardResult::query()->where('id', $rewardResultId)->update([
                'status' => 'draft',
                'summary_json' => json_encode([
                    'source' => [
                        'name' => 'central',
                        'mode' => 'redraw',
                    ],
                    'live' => [
                        'status' => 'draft',
                        'completion_percent' => 0,
                        'updated_at' => now()->toISOString(),
                    ],
                    'redraw' => [
                        'reason' => $payload['reason'] ?? null,
                        'requested_by_admin_id' => $actor->adminUser['id'],
                        'requested_at' => now()->toISOString(),
                    ],
                ], JSON_THROW_ON_ERROR),
                'checked_at' => null,
                'verified_by_admin_id' => null,
                'verified_at' => null,
                'published_by_admin_id' => null,
                'published_at' => null,
                'corrected_by_admin_id' => $actor->adminUser['id'],
                'correction_note' => $payload['reason'] ?? $payload['note'] ?? null,
                'corrected_at' => now(),
                'updated_at' => now(),
            ]);
            $this->setGameStatus((string) $result->game_id, 'reward_recorded');
            $this->broadcastRewardLiveUpdate($rewardResultId);

            return $this->rewardResult($rewardResultId) ?? [];
        }, 'reward.redraw_requested', 200);
    }

    /**
     * @param array<string, mixed> $payload
     * @return array{resource?: array<string, mixed>, status?: int, error?: string}
     */
    public function correctRewardResult(string $rewardResultId, array $payload, AdminSessionContext $actor, Request $request): array
    {
        return $this->centralWrite($rewardResultId, $payload, $actor, $request, 'admin.central.rewards.correct', 'reward.correct', function (object $result) use ($rewardResultId, $payload, $actor): array|string {
            if (! in_array((string) $result->status, ['published', 'verified'], true)) {
                return 'resource_conflict';
            }

            RewardResult::query()->where('id', $rewardResultId)->update([
                'status' => 'corrected',
                'corrected_by_admin_id' => $actor->adminUser['id'],
                'correction_note' => $payload['reason'] ?? $payload['note'] ?? null,
                'corrected_at' => now(),
                'updated_at' => now(),
            ]);

            return $this->rewardResult($rewardResultId) ?? [];
        }, 'reward.corrected', 202);
    }

    private function publishCheckedRewardResult(string $rewardResultId, object $result, AdminSessionContext $actor, Request $request): array|string
    {
        $fresh = RewardResult::query()->where('id', $rewardResultId)->first() ?? $result;

        if ((string) $fresh->status === 'published') {
            return $this->rewardResult($rewardResultId) ?? [];
        }

        if (! in_array((string) $fresh->status, ['summary_ready', 'verified'], true)) {
            return 'resource_conflict';
        }

        $version = max(
            (int) $fresh->version,
            (int) RewardPublishLog::where('reward_result_id', $rewardResultId)->max('reward_version') + 1,
        );
        $publishedAt = now();
        $summary = [
            ...$this->summary($rewardResultId),
            'reward_version' => $version,
            'status' => 'published',
        ];
        $logId = 'rpl_'.Str::ulid()->toBase32();

        WinningTicket::query()
            ->where('reward_result_id', $rewardResultId)
            ->where('status', 'pending')
            ->update([
                'status' => 'verified',
                'updated_at' => $publishedAt,
            ]);
        RewardResult::query()->where('id', $rewardResultId)->update([
            'status' => 'published',
            'version' => $version,
            'summary_json' => json_encode($summary, JSON_THROW_ON_ERROR),
            'verified_by_admin_id' => $fresh->verified_by_admin_id ?? $actor->adminUser['id'],
            'verified_at' => $fresh->verified_at ?? $publishedAt,
            'published_by_admin_id' => $actor->adminUser['id'],
            'published_at' => $publishedAt,
            'updated_at' => $publishedAt,
        ]);
        RewardPublishLog::query()->insert([
            'id' => $logId,
            'reward_result_id' => $rewardResultId,
            'game_id' => (string) $fresh->game_id,
            'reward_version' => $version,
            'published_by_admin_id' => $actor->adminUser['id'],
            'payload_json' => json_encode($summary, JSON_THROW_ON_ERROR),
            'published_at' => $publishedAt,
            'created_at' => $publishedAt,
            'updated_at' => $publishedAt,
        ]);
        $this->setGameStatus((string) $fresh->game_id, 'reward_published');
        $this->insertOutboxEvent('reward.published.v1', (string) $fresh->game_id, 'reward_result', $rewardResultId, $request->header('Idempotency-Key'), $request->header('X-Request-Id'), [
            'reward_result_id' => $rewardResultId,
            'game_id' => (string) $fresh->game_id,
            'reward_version' => $version,
            'published_at' => $publishedAt->toISOString(),
        ]);
        $this->createAutomaticRewardClaimsForResult($rewardResultId, $publishedAt);
        $activityResultAt = $this->tenantActivityResultAt((string) $fresh->game_id) ?? $publishedAt;
        ProcessTenantActivitiesForGameJob::dispatch((string) $fresh->game_id, 'lucky')->delay($activityResultAt);
        ProcessTenantActivitiesForGameJob::dispatch((string) $fresh->game_id, 'cashback')->delay($activityResultAt);
        $this->broadcastRewardLiveUpdate($rewardResultId);

        return $this->rewardResult($rewardResultId) ?? [];
    }

    private function tenantActivityResultAt(string $gameId): mixed
    {
        $drawAt = Game::query()->whereKey($gameId)->value('draw_at');

        if ($drawAt === null || trim((string) $drawAt) === '') {
            return null;
        }

        return \Illuminate\Support\Carbon::parse($drawAt)
            ->timezone('Asia/Bangkok')
            ->setTime(17, 0, 0);
    }

    /**
     * @return array{body: array<string, mixed>|null, etag: string|null}
     */
    public function publicLatestResult(): array
    {
        $result = RewardResult::query()
            ->join('games', 'games.id', '=', 'reward_results.game_id')
            ->where('reward_results.status', 'published')
            ->select('reward_results.*')
            ->orderByDesc('games.draw_at')
            ->first();

        return $this->publicResultEnvelope($result);
    }

    /**
     * @return array{body: array<string, mixed>|null, etag: string|null}
     */
    public function publicResultForGame(string $gameId): array
    {
        $result = RewardResult::where('game_id', $gameId)
            ->where('status', 'published')
            ->first();

        return $this->publicResultEnvelope($result);
    }

    /**
     * @return array<string, mixed>|null
     */
    public function ticketRewardStatus(string $tenantId, CustomerSessionContext $customer, string $ticketId): ?array
    {
        $ticket = Ticket::query()
            ->forTenant($tenantId)
            ->where('customer_id', $customer->customerId())
            ->where('id', $ticketId)
            ->first();

        if ($ticket === null) {
            return null;
        }

        $winnings = $this->ticketWinningRows($tenantId, $ticketId);
        $visibleWinnings = array_values(array_filter(
            $winnings,
            fn (object $winning): bool => in_array((string) $winning->reward_result_status, ['verified', 'published'], true),
        ));
        $winning = $visibleWinnings[0] ?? null;
        $claim = RewardClaim::query()
            ->forTenant($tenantId)
            ->where('ticket_id', $ticketId)
            ->orderByRaw("CASE WHEN status IN ('rejected', 'cancelled') THEN 1 ELSE 0 END")
            ->orderByDesc('created_at')
            ->orderByDesc('id')
            ->first();

        if ($claim !== null) {
            $customerStatus = $this->claimStatusForTicket($claim);
            $claimableAfterRejected = in_array((string) $claim->status, ['rejected', 'cancelled'], true)
                && $this->claimableWinningRows($visibleWinnings) !== [];

            return [
                'ticket_id' => $ticketId,
                'status' => $customerStatus,
                'claim_status' => (string) $claim->status,
                'claimable' => $claimableAfterRejected,
                'prize_type' => $winning?->prize_type,
                'prize_number' => $winning?->prize_number,
                'prize_amount' => $this->money($this->claimEffectivePrizeAmount($claim, $visibleWinnings), (string) $claim->currency),
                'prizes' => $this->winningPrizeRowsResource($visibleWinnings),
                'prize_count' => count($visibleWinnings),
                'reward_result_id' => $winning?->reward_result_id,
                'reward_claim_id' => (string) $claim->id,
                'payout_method' => (string) $claim->payout_method,
                'paid_at' => $claim->paid_at,
                'reviewed_at' => $claim->reviewed_at,
                'admin_note' => $claim->admin_note,
            ];
        }

        if ($winning !== null) {
            $claimableWinnings = $this->claimableWinningRows($visibleWinnings);

            return [
                'ticket_id' => $ticketId,
                'status' => 'winning',
                'claimable' => $claimableWinnings !== [],
                'prize_type' => (string) $winning->prize_type,
                'prize_number' => (string) $winning->prize_number,
                'prize_amount' => $this->money($this->sumWinningAmount($visibleWinnings), (string) $winning->currency),
                'prizes' => $this->winningPrizeRowsResource($visibleWinnings),
                'prize_count' => count($visibleWinnings),
                'reward_result_id' => (string) $winning->reward_result_id,
                'reward_claim_id' => null,
            ];
        }

        if (RewardResult::where('game_id', $ticket->game_id)->where('status', 'published')->exists()) {
            return [
                'ticket_id' => $ticketId,
                'status' => 'non_winning',
                'claimable' => false,
                'prize_type' => null,
                'prize_number' => null,
                'prize_amount' => null,
                'prizes' => [],
                'prize_count' => 0,
                'reward_result_id' => null,
                'reward_claim_id' => null,
            ];
        }

        return [
            'ticket_id' => $ticketId,
            'status' => 'pending_result',
            'claimable' => false,
            'prize_type' => null,
            'prize_number' => null,
            'prize_amount' => null,
            'prizes' => [],
            'prize_count' => 0,
            'reward_result_id' => null,
            'reward_claim_id' => null,
        ];
    }

    /**
     * @param array<string, mixed> $queryParams
     * @return array<string, mixed>
     */
    public function customerClaims(string $tenantId, CustomerSessionContext $customer, array $queryParams): array
    {
        $limit = $this->limit($queryParams['limit'] ?? null);
        $query = RewardClaim::query()
            ->forTenant($tenantId)
            ->where('customer_id', $customer->customerId())
            ->orderBy('id')
            ->limit($limit + 1);

        if (($queryParams['cursor'] ?? null) !== null && trim((string) $queryParams['cursor']) !== '') {
            $query->where('id', '>', trim((string) $queryParams['cursor']));
        }

        return $this->claimListResponse($query->get()->all(), $limit);
    }

    /**
     * @return array<string, mixed>|null
     */
    public function customerClaim(string $tenantId, CustomerSessionContext $customer, string $claimId): ?array
    {
        $claim = RewardClaim::query()
            ->forTenant($tenantId)
            ->where('customer_id', $customer->customerId())
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
        $pin = trim((string) ($payload['pin'] ?? ''));
        $normalized = [
            'ticket_id' => trim((string) ($payload['ticket_id'] ?? '')),
            'payout_method' => trim((string) ($payload['payout_method'] ?? '')),
            'bank_account' => $this->normalizeBankAccount($payload['bank_account'] ?? null),
            'note' => trim((string) ($payload['note'] ?? '')),
        ];

        $pinResult = $this->customerAuth->verifyPin($customer, ['pin' => $pin]);

        if (($pinResult['error'] ?? null) !== null) {
            return [
                'error' => $pinResult['error'],
                'retry_after_seconds' => $pinResult['retry_after_seconds'] ?? null,
            ];
        }

        if ($normalized['payout_method'] === 'bank_transfer' && ! $this->hasUsableBankAccount($normalized['bank_account'])) {
            $normalized['bank_account'] = $this->customerRewardPayoutBankAccount($tenantId, $customer->customerId());
        }

        $idempotencyKey = (string) $request->header('Idempotency-Key');

        return DB::transaction(function () use ($tenantId, $customer, $payload, $normalized, $request, $idempotencyKey): array {
            $routeKey = 'customer.reward_claims.store';
            $replay = $this->idempotency->replayOrConflict($tenantId, 'customer', $customer->customerId(), $routeKey, $idempotencyKey, $normalized, lock: true);

            if (is_array($replay)) {
                return ['resource' => $replay['body'] ?? [], 'status' => $replay['status']];
            }

            if ($replay !== null) {
                return ['error' => $replay];
            }

            if (! in_array($normalized['payout_method'], ['wallet_credit', 'bank_transfer'], true) || $normalized['ticket_id'] === '') {
                return ['error' => 'validation_failed'];
            }

            if ($normalized['payout_method'] === 'bank_transfer' && ! $this->hasUsableBankAccount($normalized['bank_account'])) {
                return ['error' => 'validation_failed'];
            }

            $ticket = Ticket::query()
                ->where('tenant_id', $tenantId)
                ->where('customer_id', $customer->customerId())
                ->where('id', $normalized['ticket_id'])
                ->lockForUpdate()
                ->first();

            if ($ticket === null) {
                return ['error' => 'not_found'];
            }

            $winnings = WinningTicket::query()
                ->join('reward_results', 'reward_results.id', '=', 'winning_tickets.reward_result_id')
                ->where('winning_tickets.tenant_id', $tenantId)
                ->where('winning_tickets.ticket_id', $ticket->id)
                ->where('reward_results.status', 'published')
                ->select('winning_tickets.*')
                ->lockForUpdate()
                ->get()
                ->all();
            $winnings = $this->sortWinningRows($winnings);
            $claimableWinnings = array_values(array_filter(
                $winnings,
                fn (object $winning): bool => in_array((string) $winning->status, ['pending', 'verified'], true),
            ));
            $winning = $claimableWinnings[0] ?? null;

            if ($winning === null) {
                return ['error' => 'resource_conflict'];
            }

            if (RewardClaim::where('tenant_id', $tenantId)->where('ticket_id', $ticket->id)->whereNotIn('status', ['rejected', 'cancelled'])->exists()) {
                return ['error' => 'resource_conflict'];
            }

            $walletId = null;

            if ($normalized['payout_method'] === 'wallet_credit') {
                $walletId = $this->customerAuth->ensurePrimaryWallet($tenantId, $customer->customerId());
            }

            $claimId = 'rcl_'.Str::ulid()->toBase32();
            $now = now();
            $priceRuleSnapshot = $winning->price_rule_snapshot_json;
            $prizeAmount = $this->sumWinningAmount($claimableWinnings, 'amount');
            $basePrizeAmount = $this->sumWinningAmount($claimableWinnings, 'base_amount', 'amount');
            $adjustmentAmount = $this->sumWinningAmount($claimableWinnings, 'adjustment_amount');
            $bankAccountJson = $normalized['bank_account'] === [] ? null : json_encode($normalized['bank_account'], JSON_THROW_ON_ERROR);
            $priceRuleSnapshotJson = is_array($priceRuleSnapshot) ? json_encode($priceRuleSnapshot, JSON_THROW_ON_ERROR) : $priceRuleSnapshot;

            if ($normalized['payout_method'] === 'bank_transfer') {
                $this->storeCustomerRewardPayoutBankAccount($tenantId, $customer->customerId(), $normalized['bank_account']);
            }

            $claimPayload = [
                'wallet_id' => $walletId,
                'status' => 'submitted',
                'payout_method' => $normalized['payout_method'],
                'prize_amount' => $prizeAmount,
                'base_prize_amount' => $basePrizeAmount,
                'adjustment_amount' => $adjustmentAmount,
                'tenant_price_rule_id' => $winning->tenant_price_rule_id,
                'price_rule_snapshot_json' => $priceRuleSnapshotJson,
                'currency' => (string) $winning->currency,
                'bank_account_json' => $bankAccountJson,
                'customer_note' => $payload['note'] ?? null,
                'admin_note' => null,
                'idempotency_key' => $idempotencyKey,
                'payload_hash' => $this->idempotency->payloadHash($normalized),
                'reviewed_by_admin_id' => null,
                'paid_by_admin_id' => null,
                'payout_ledger_id' => null,
                'submitted_at' => $now,
                'reviewed_at' => null,
                'paid_at' => null,
                'updated_at' => $now,
            ];

            RewardClaim::query()->insert(array_merge([
                'id' => $claimId,
                'tenant_id' => $tenantId,
                'customer_id' => $customer->customerId(),
                'ticket_id' => (string) $ticket->id,
                'winning_ticket_id' => (string) $winning->id,
                'game_id' => (string) $winning->game_id,
                'reference' => 'RWD-'.strtoupper(substr($claimId, -10)),
                'created_at' => $now,
            ], $claimPayload));

            $resource = $this->claimResource(RewardClaim::where('id', $claimId)->first());
            $this->idempotency->storeResponse($tenantId, 'customer', $customer->customerId(), $routeKey, $idempotencyKey, $normalized, 201, $resource);
            $this->queueRewardClaimUpdatedBroadcast($tenantId, $claimId);
            $this->lineNotifications->enqueue($tenantId, $customer->customerId(), 'reward_claim.submitted', 'reward_claim', $claimId, $this->lineClaimVariables($tenantId, $resource, 'ส่งคำขอขึ้นเงินรางวัลแล้ว'));
            $this->telegramNotifications->enqueue($tenantId, 'reward_claim.submitted', 'reward_claim', $claimId, $this->telegramClaimVariables($tenantId, $resource));

            return ['resource' => $resource, 'status' => 201];
        });
    }

    /**
     * @param array<string, mixed> $queryParams
     * @return array<string, mixed>
     */
    public function tenantClaims(string $tenantId, array $queryParams): array
    {
        $limit = $this->limit($queryParams['limit'] ?? null);
        $query = RewardClaim::query()
            ->select('reward_claims.*')
            ->leftJoin('customers', function ($join) use ($tenantId): void {
                $join->on('customers.id', '=', 'reward_claims.customer_id')
                    ->where('customers.tenant_id', '=', $tenantId);
            })
            ->forTenant($tenantId)
            ->limit($limit + 1);

        foreach (['status', 'game_id', 'customer_id'] as $field) {
            if (($queryParams[$field] ?? null) !== null && trim((string) $queryParams[$field]) !== '') {
                $query->where('reward_claims.'.$field, trim((string) $queryParams[$field]));
            }
        }

        $section = trim((string) ($queryParams['section'] ?? ''));
        if ($section === 'pending') {
            $query->whereIn('reward_claims.status', self::PENDING_CLAIM_STATUSES);
        } elseif ($section === 'history') {
            $query->whereNotIn('reward_claims.status', self::PENDING_CLAIM_STATUSES);
        }

        if (($queryParams['q'] ?? null) !== null && trim((string) $queryParams['q']) !== '') {
            $q = trim((string) $queryParams['q']);
            $query->where(function ($nested) use ($q): void {
                $nested->where('reward_claims.reference', 'like', '%'.$q.'%')
                    ->orWhere('reward_claims.ticket_id', 'like', '%'.$q.'%')
                    ->orWhere('reward_claims.customer_id', 'like', '%'.$q.'%')
                    ->orWhere('customers.customer_no', 'like', '%'.strtoupper($q).'%')
                    ->orWhere('customers.name', 'like', '%'.$q.'%');
            });
        }

        $sortDirection = $this->applyRewardClaimSort($query, $queryParams);

        if (($queryParams['cursor'] ?? null) !== null && trim((string) $queryParams['cursor']) !== '') {
            $operator = $sortDirection === 'desc' ? '<' : '>';
            $query->where('reward_claims.id', $operator, trim((string) $queryParams['cursor']));
        }

        return $this->claimListResponse($query->get()->all(), $limit);
    }

    /**
     * @param array<string, mixed> $queryParams
     */
    private function applyRewardClaimSort(mixed $query, array $queryParams): string
    {
        $section = trim((string) ($queryParams['section'] ?? ''));
        $defaultSort = $section === 'history' ? 'updated_at' : 'submitted_at';
        $sortBy = (string) ($queryParams['sort_by'] ?? $defaultSort);
        $defaultDirection = $section === 'pending' && $sortBy === 'submitted_at' ? 'asc' : (in_array($sortBy, ['id', 'created_at', 'updated_at', 'reviewed_at', 'paid_at'], true) ? 'desc' : 'asc');
        $direction = strtolower((string) ($queryParams['sort_dir'] ?? $defaultDirection)) === 'desc' ? 'desc' : 'asc';
        $columns = [
            'id' => 'reward_claims.id',
            'reference' => 'reward_claims.reference',
            'customer_no' => 'customers.customer_no',
            'customer.customer_no' => 'customers.customer_no',
            'member_no' => 'customers.customer_no',
            'customer_name' => 'customers.name',
            'customer.name' => 'customers.name',
            'ticket.full_number' => 'reward_claims.ticket_id',
            'prize_amount' => 'reward_claims.prize_amount',
            'prize_amount.amount' => 'reward_claims.prize_amount',
            'payout_method' => 'reward_claims.payout_method',
            'status' => 'reward_claims.status',
            'submitted_at' => 'reward_claims.submitted_at',
            'reviewed_at' => 'reward_claims.reviewed_at',
            'paid_at' => 'reward_claims.paid_at',
            'created_at' => 'reward_claims.created_at',
            'updated_at' => 'reward_claims.updated_at',
        ];
        $column = $columns[$sortBy] ?? 'reward_claims.'.$defaultSort;

        $query->reorder($column, $direction);

        if ($column !== 'reward_claims.id') {
            $query->orderBy('reward_claims.id', $direction);
        }

        return $direction;
    }

    /**
     * @return array<string, mixed>|null
     */
    public function tenantClaim(string $tenantId, string $claimId): ?array
    {
        $claim = RewardClaim::query()->forTenant($tenantId)->where('id', $claimId)->first();

        return $claim === null ? null : $this->claimResource($claim);
    }

    /**
     * @param array<string, mixed> $payload
     * @return array{resource?: array<string, mixed>, status?: int, error?: string}
     */
    public function approveTenantClaim(string $tenantId, AdminSessionContext $actor, string $claimId, array $payload, Request $request): array
    {
        return $this->tenantClaimWrite($tenantId, $actor, $claimId, $payload, $request, 'admin.tenant.reward_claims.approve', 'reward_claim.approve', 'reward_claim.approved', function (object $claim) use ($actor, $payload, $request): array|string {
            if ((string) $claim->status === 'approved') {
                return [];
            }

            if (! in_array((string) $claim->status, ['submitted', 'under_review'], true)) {
                return 'resource_conflict';
            }

            $amount = $this->moneyAmount($payload['approved_amount'] ?? null, $this->claimEffectivePrizeAmount($claim));

            if ($amount <= 0) {
                return 'resource_conflict';
            }

            $ledger = null;
            $walletId = $claim->wallet_id;
            $payoutMethod = (string) $claim->payout_method;
            $settledOnApprove = in_array($payoutMethod, ['wallet_credit', 'bank_transfer'], true);
            $paidAt = $settledOnApprove ? now() : null;

            if ($payoutMethod === 'wallet_credit') {
                $walletId = $walletId ?? $this->customerAuth->ensurePrimaryWallet((string) $claim->tenant_id, (string) $claim->customer_id);
                $ledger = $this->commerce->postLedger((string) $claim->tenant_id, (string) $walletId, (string) $claim->customer_id, 'credit', $amount, 'reward_claim', (string) $claim->id, 'reward-approve-'.(string) $request->header('Idempotency-Key'), $actor->adminUser['id'], $payload);
                $this->insertWalletOutbox((string) $claim->tenant_id, (string) $claim->customer_id, (string) $walletId, $ledger, (string) $request->header('Idempotency-Key'), $request->header('X-Request-Id'));
            }

            RewardClaim::query()->where('id', $claim->id)->update([
                'status' => 'approved',
                'prize_amount' => $amount,
                'wallet_id' => $walletId,
                'payout_ledger_id' => $ledger['id'] ?? $claim->payout_ledger_id,
                'reviewed_by_admin_id' => $actor->adminUser['id'],
                'reviewed_at' => now(),
                'paid_by_admin_id' => $settledOnApprove ? $actor->adminUser['id'] : null,
                'paid_at' => $paidAt,
                'admin_note' => $payload['reason'] ?? null,
                'updated_at' => now(),
            ]);
            WinningTicket::query()->where('tenant_id', $claim->tenant_id)->where('ticket_id', $claim->ticket_id)->update([
                'status' => $settledOnApprove ? 'paid' : 'approved',
                'updated_at' => now(),
            ]);

            if ($settledOnApprove) {
                Ticket::query()->where('id', $claim->ticket_id)->where('tenant_id', $claim->tenant_id)->update([
                    'status' => 'paid_out',
                    'updated_at' => now(),
                ]);
            }

            return [];
        });
    }

    /**
     * @param array<string, mixed> $payload
     * @return array{resource?: array<string, mixed>, status?: int, error?: string}
     */
    public function rejectTenantClaim(string $tenantId, AdminSessionContext $actor, string $claimId, array $payload, Request $request): array
    {
        return $this->tenantClaimWrite($tenantId, $actor, $claimId, $payload, $request, 'admin.tenant.reward_claims.reject', 'reward_claim.reject', 'reward_claim.rejected', function (object $claim) use ($actor, $payload): array|string {
            if ((string) $claim->status === 'rejected') {
                return [];
            }

            if (! in_array((string) $claim->status, ['submitted', 'under_review', 'approved'], true)) {
                return 'resource_conflict';
            }

            RewardClaim::query()->where('id', $claim->id)->update([
                'status' => 'rejected',
                'reviewed_by_admin_id' => $actor->adminUser['id'],
                'reviewed_at' => now(),
                'admin_note' => $payload['reason'] ?? null,
                'updated_at' => now(),
            ]);

            return [];
        });
    }

    /**
     * @param array<string, mixed> $payload
     * @return array{resource?: array<string, mixed>, status?: int, error?: string}
     */
    public function payTenantClaim(string $tenantId, AdminSessionContext $actor, string $claimId, array $payload, Request $request): array
    {
        return $this->tenantClaimWrite($tenantId, $actor, $claimId, $payload, $request, 'admin.tenant.reward_claims.pay', 'reward_claim.pay', 'reward_claim.paid', function (object $claim) use ($actor, $payload, $request): array|string {
            if ((string) $claim->status === 'paid') {
                return [];
            }

            if ((string) $claim->status !== 'approved') {
                return 'resource_conflict';
            }

            $method = trim((string) ($payload['payout_method'] ?? $claim->payout_method));
            $amount = $this->moneyAmount($payload['paid_amount'] ?? null, $this->claimEffectivePrizeAmount($claim));
            $ledger = null;
            $walletId = $claim->wallet_id;

            if (! in_array($method, self::CLAIM_PAYOUT_METHODS, true) || $amount <= 0) {
                return 'resource_conflict';
            }

            if ($method === 'wallet_credit') {
                $walletId = $walletId ?? $this->customerAuth->ensurePrimaryWallet((string) $claim->tenant_id, (string) $claim->customer_id);
                if ($claim->payout_ledger_id === null) {
                    $ledger = $this->commerce->postLedger((string) $claim->tenant_id, (string) $walletId, (string) $claim->customer_id, 'credit', $amount, 'reward_claim', (string) $claim->id, 'reward-pay-'.(string) $request->header('Idempotency-Key'), $actor->adminUser['id'], $payload);
                    $this->insertWalletOutbox((string) $claim->tenant_id, (string) $claim->customer_id, (string) $walletId, $ledger, (string) $request->header('Idempotency-Key'), $request->header('X-Request-Id'));
                }
            }

            RewardClaim::query()->where('id', $claim->id)->update([
                'status' => 'paid',
                'payout_method' => $method,
                'prize_amount' => $amount,
                'wallet_id' => $walletId,
                'payout_ledger_id' => $ledger['id'] ?? $claim->payout_ledger_id,
                'paid_by_admin_id' => $actor->adminUser['id'],
                'paid_at' => now(),
                'admin_note' => $payload['reason'] ?? null,
                'updated_at' => now(),
            ]);
            WinningTicket::query()->where('tenant_id', $claim->tenant_id)->where('ticket_id', $claim->ticket_id)->update(['status' => 'paid', 'updated_at' => now()]);
            Ticket::query()->where('id', $claim->ticket_id)->where('tenant_id', $claim->tenant_id)->update(['status' => 'paid_out', 'updated_at' => now()]);

            return [];
        });
    }

    private function processSingleRewardCheck(object $result, int $chunkSize, ?string $idempotencyKey): int
    {
        return DB::transaction(function () use ($result, $chunkSize, $idempotencyKey): int {
            $locked = RewardResult::query()->where('id', $result->id)->lockForUpdate()->first();

            if ($locked === null || ! in_array((string) $locked->status, ['recorded', 'checking'], true)) {
                return 0;
            }

            RewardResult::query()->where('id', $locked->id)->update(['status' => 'checking', 'updated_at' => now()]);
            $this->setGameStatus((string) $locked->game_id, 'reward_checking');
            WinningTicket::query()->where('reward_result_id', $locked->id)->delete();
            RewardCheckItem::query()->where('reward_result_id', $locked->id)->delete();
            RewardCheckBatch::query()->where('reward_result_id', $locked->id)->delete();

            $batchId = 'rcb_'.Str::ulid()->toBase32();
            $now = now();
            $prizes = RewardPrize::query()->where('reward_result_id', $locked->id)->orderBy('sort_order')->get()->all();
            $tickets = Ticket::query()
                ->where('game_id', $locked->game_id)
                ->whereIn('status', ['active', 'reward_pending', 'winning', 'non_winning'])
                ->orderBy('tenant_id')
                ->orderBy('id')
                ->get()
                ->all();
            $chunks = array_chunk($tickets, $chunkSize);
            $processed = 0;
            $winningRows = 0;

            RewardCheckBatch::query()->insert([
                'id' => $batchId,
                'reward_result_id' => $locked->id,
                'game_id' => $locked->game_id,
                'status' => 'processing',
                'chunk_count' => count($chunks),
                'processed_ticket_count' => 0,
                'winning_count' => 0,
                'idempotency_key' => $idempotencyKey,
                'payload_hash' => hash('sha256', (string) $locked->id),
                'started_at' => $now,
                'created_at' => $now,
                'updated_at' => $now,
            ]);

            foreach ($chunks as $chunk) {
                $itemId = 'rci_'.Str::ulid()->toBase32();
                $chunkWins = 0;

                foreach ($chunk as $ticket) {
                    $ticketWon = false;

                    foreach ($prizes as $prize) {
                        if (! $this->ticketMatchesPrize((string) $ticket->full_number, $prize)) {
                            continue;
                        }

                        $pricing = $this->tenantRewardPriceRules->resolveForPrize((string) $ticket->tenant_id, (string) $ticket->game_id, $prize);

                        WinningTicket::query()->updateOrInsert(
                            [
                                'game_id' => (string) $ticket->game_id,
                                'ticket_id' => (string) $ticket->id,
                                'prize_type' => (string) $prize->prize_type,
                                'prize_number' => (string) $prize->prize_number,
                            ],
                            [
                                'id' => 'wti_'.substr(sha1($locked->id.':'.$ticket->id.':'.$prize->id), 0, 20),
                                'tenant_id' => (string) $ticket->tenant_id,
                                'reward_result_id' => (string) $locked->id,
                                'reward_prize_id' => (string) $prize->id,
                                'amount' => (int) $pricing['effective_amount'],
                                'base_amount' => (int) $pricing['base_amount'],
                                'adjustment_amount' => (int) $pricing['adjustment_amount'],
                                'tenant_price_rule_id' => $pricing['tenant_price_rule_id'],
                                'price_rule_snapshot_json' => $pricing['price_rule_snapshot'] === null ? null : json_encode($pricing['price_rule_snapshot'], JSON_THROW_ON_ERROR),
                                'currency' => (string) $prize->currency,
                                'status' => 'pending',
                                'created_at' => $now,
                                'updated_at' => $now,
                            ],
                        );
                        $ticketWon = true;
                        $chunkWins++;
                    }

                    Ticket::query()->where('id', $ticket->id)->update([
                        'status' => $ticketWon ? 'winning' : 'non_winning',
                        'updated_at' => $now,
                    ]);
                }

                $processed += count($chunk);
                $winningRows += $chunkWins;

                RewardCheckItem::query()->insert([
                    'id' => $itemId,
                    'reward_check_batch_id' => $batchId,
                    'reward_result_id' => $locked->id,
                    'tenant_id' => $chunk[0]->tenant_id ?? null,
                    'cursor_from' => $chunk[0]->id ?? null,
                    'cursor_to' => end($chunk)->id ?? null,
                    'status' => 'completed',
                    'checked_count' => count($chunk),
                    'winning_count' => $chunkWins,
                    'created_at' => $now,
                    'updated_at' => $now,
                ]);
            }

            RewardCheckBatch::query()->where('id', $batchId)->update([
                'status' => 'completed',
                'processed_ticket_count' => $processed,
                'winning_count' => $winningRows,
                'completed_at' => now(),
                'updated_at' => now(),
            ]);

            RewardResult::query()->where('id', $locked->id)->update([
                'status' => 'summary_ready',
                'summary_json' => json_encode($this->summary((string) $locked->id), JSON_THROW_ON_ERROR),
                'checked_at' => now(),
                'updated_at' => now(),
            ]);

            return $processed;
        });
    }

    /**
     * @param array<string, mixed> $payload
     * @param callable(object): array<string, mixed>|string $mutator
     * @return array{resource?: array<string, mixed>, status?: int, error?: string}
     */
    private function centralWrite(string $rewardResultId, array $payload, AdminSessionContext $actor, Request $request, string $routeKey, string $permissionCode, callable $mutator, string $auditAction, int $successStatus = 200): array
    {
        $idempotencyKey = (string) $request->header('Idempotency-Key');

        return DB::transaction(function () use ($rewardResultId, $payload, $actor, $request, $routeKey, $permissionCode, $mutator, $auditAction, $successStatus, $idempotencyKey): array {
            $route = $routeKey.':'.$rewardResultId;
            $replay = $this->idempotency->replayOrConflict(null, 'central_admin', $actor->adminUser['id'], $route, $idempotencyKey, $payload, $permissionCode, true);

            if (is_array($replay)) {
                return ['resource' => $replay['body'] ?? [], 'status' => $replay['status']];
            }

            if ($replay !== null) {
                return ['error' => $replay];
            }

            $result = RewardResult::query()->where('id', $rewardResultId)->lockForUpdate()->first();

            if ($result === null) {
                return ['error' => 'not_found'];
            }

            $mutated = $mutator($result);

            if (is_string($mutated)) {
                return ['error' => $mutated];
            }

            $resource = $this->rewardResult($rewardResultId) ?? [];
            $this->idempotency->storeResponse(null, 'central_admin', $actor->adminUser['id'], $route, $idempotencyKey, $payload, $successStatus, $resource, $permissionCode);
            $this->auditAdmin($actor, $request, $auditAction, 'reward_result', $rewardResultId, $payload);

            return ['resource' => $resource, 'status' => $successStatus];
        });
    }

    /**
     * @param array<string, mixed> $payload
     * @param callable(object): array<string, mixed>|string $mutator
     * @return array{resource?: array<string, mixed>, status?: int, error?: string}
     */
    private function tenantClaimWrite(string $tenantId, AdminSessionContext $actor, string $claimId, array $payload, Request $request, string $routeKey, string $permissionCode, string $auditAction, callable $mutator): array
    {
        $idempotencyKey = (string) $request->header('Idempotency-Key');

        return DB::transaction(function () use ($tenantId, $actor, $claimId, $payload, $request, $routeKey, $permissionCode, $auditAction, $mutator, $idempotencyKey): array {
            $route = $routeKey.':'.$claimId;
            $replay = $this->idempotency->replayOrConflict($tenantId, 'tenant_admin', $actor->adminUser['id'], $route, $idempotencyKey, $payload, $permissionCode, true);

            if (is_array($replay)) {
                return ['resource' => $replay['body'] ?? [], 'status' => $replay['status']];
            }

            if ($replay !== null) {
                return ['error' => $replay];
            }

            $claim = RewardClaim::query()->where('tenant_id', $tenantId)->where('id', $claimId)->lockForUpdate()->first();

            if ($claim === null) {
                return ['error' => 'not_found'];
            }

            $mutated = $mutator($claim);

            if (is_string($mutated)) {
                return ['error' => $mutated];
            }

            $resource = $this->claimResource(RewardClaim::where('id', $claimId)->first());
            $this->idempotency->storeResponse($tenantId, 'tenant_admin', $actor->adminUser['id'], $route, $idempotencyKey, $payload, 200, $resource, $permissionCode);
            $this->auditAdmin($actor, $request, $auditAction, 'reward_claim', $claimId, $payload, $tenantId);
            $this->queueRewardClaimUpdatedBroadcast($tenantId, $claimId);
            $statusLabel = $this->lineRewardClaimStatusLabel((string) ($resource['status'] ?? $claim->status));
            $this->lineNotifications->enqueue($tenantId, (string) ($resource['customer']['id'] ?? $claim->customer_id), 'reward_claim.status_updated', 'reward_claim', $claimId, $this->lineClaimVariables($tenantId, $resource, $statusLabel));
            $this->telegramNotifications->enqueue($tenantId, 'reward_claim.status_updated', 'reward_claim', $claimId, $this->telegramClaimVariables($tenantId, $resource, $statusLabel, $actor->adminUser));

            return ['resource' => $resource, 'status' => 200];
        });
    }

    /**
     * @param array<int, array<string, mixed>> $prizes
     */
    private function replacePrizes(string $resultId, string $gameId, array $prizes): void
    {
        RewardPrize::query()->where('reward_result_id', $resultId)->delete();
        $now = now();
        $rows = [];

        foreach (array_values($prizes) as $index => $prize) {
            $rows[] = [
                'id' => 'rpr_'.Str::ulid()->toBase32(),
                'reward_result_id' => $resultId,
                'game_id' => $gameId,
                'prize_type' => trim((string) $prize['prize_type']),
                'prize_number' => trim((string) $prize['prize_number']),
                'amount' => $this->moneyAmount($prize['amount'], 0),
                'currency' => $this->moneyCurrency($prize['amount'] ?? null),
                'sort_order' => $index,
                'created_at' => $now,
                'updated_at' => $now,
            ];
        }

        RewardPrize::query()->insert($rows);
    }

    /**
     * @param array<string, mixed> $normalized
     */
    private function applyPartialRewardUpdates(string $rewardResultId, array $normalized): void
    {
        if (isset($normalized['prize_number_updates'])) {
            foreach ($normalized['prize_number_updates'] as $update) {
                $rows = RewardPrize::query()
                    ->where('reward_result_id', $rewardResultId)
                    ->where('prize_type', $update['prize_type'])
                    ->orderBy('sort_order')
                    ->get(['id', 'prize_number'])
                    ->all();

                foreach ($update['prize_numbers'] as $index => $number) {
                    if (! isset($rows[$index])) {
                        continue;
                    }

                    $nextNumber = $this->normalizePrizeNumberUpdateValue($update['prize_type'], $index, $number);

                    if ((string) $rows[$index]->prize_number === $nextNumber) {
                        continue;
                    }

                    RewardPrize::query()->where('id', $rows[$index]->id)->update([
                        'prize_number' => $nextNumber,
                        'updated_at' => now(),
                    ]);
                }
            }
        }

        if (isset($normalized['payout_amount_updates'])) {
            foreach ($normalized['payout_amount_updates'] as $update) {
                RewardPrize::query()
                    ->where('reward_result_id', $rewardResultId)
                    ->where('prize_type', $update['prize_type'])
                    ->update([
                        'amount' => $update['amount'],
                        'currency' => $update['currency'],
                        'updated_at' => now(),
                    ]);
            }
        }
    }

    /**
     * @param array<int, array<string, mixed>> $rows
     * @param array<string, mixed> $updates
     * @return array<int, array<string, mixed>>
     */
    private function applyPartialRewardUpdatesToRows(array $rows, array $updates): array
    {
        foreach ($updates['prize_number_updates'] ?? [] as $update) {
            $indexes = array_keys(array_filter(
                $rows,
                fn (array $row): bool => ($row['prize_type'] ?? '') === $update['prize_type'],
            ));

            foreach ($update['prize_numbers'] as $index => $number) {
                if (! isset($indexes[$index])) {
                    continue;
                }

                $rows[$indexes[$index]]['prize_number'] = $this->normalizePrizeNumberUpdateValue($update['prize_type'], $index, $number);
            }
        }

        foreach ($updates['payout_amount_updates'] ?? [] as $update) {
            foreach ($rows as $index => $row) {
                if (($row['prize_type'] ?? '') !== $update['prize_type']) {
                    continue;
                }

                $rows[$index]['amount'] = [
                    'amount' => $update['amount'],
                    'currency' => $update['currency'],
                ];
            }
        }

        return array_values($rows);
    }

    /**
     * @return array<int, array<string, mixed>>
     */
    private function rewardPrizePayloadRows(string $rewardResultId): array
    {
        return array_map(
            fn (object $prize): array => $this->prizeResource($prize),
            RewardPrize::query()->where('reward_result_id', $rewardResultId)->orderBy('sort_order')->get()->all(),
        );
    }

    private function rewardPrizesAreComplete(string $rewardResultId): bool
    {
        return $this->validatePrizeRows($this->rewardPrizePayloadRows($rewardResultId), true) === [];
    }

    /**
     * @param array<string, mixed> $payload
     * @return array<string, mixed>
     */
    private function normalizeRewardPayload(array $payload, bool $creating = true): array
    {
        $normalized = [];

        if ($creating || array_key_exists('game_id', $payload)) {
            $normalized['game_id'] = trim((string) ($payload['game_id'] ?? ''));
        }

        if ($creating || array_key_exists('prizes', $payload)) {
            $normalized['prizes'] = array_map(function (mixed $prize): array {
                $row = is_array($prize) ? $prize : [];

                return [
                    'prize_type' => trim((string) ($row['prize_type'] ?? '')),
                    'prize_number' => trim((string) ($row['prize_number'] ?? '')),
                    'amount' => $this->moneyAmount($row['amount'] ?? null, 0),
                    'currency' => $this->moneyCurrency($row['amount'] ?? null),
                ];
            }, is_array($payload['prizes'] ?? null) ? $payload['prizes'] : []);
        }

        if (! $creating) {
            $normalized = array_merge($normalized, $this->normalizePartialRewardUpdates($payload));
        }

        return $normalized;
    }

    /**
     * @param array<string, mixed> $payload
     * @return array<string, mixed>
     */
    private function normalizePartialRewardUpdates(array $payload): array
    {
        $normalized = [];

        if (array_key_exists('prize_number_updates', $payload) && is_array($payload['prize_number_updates'])) {
            $normalized['prize_number_updates'] = array_values(array_filter(array_map(function (mixed $update): array {
                $row = is_array($update) ? $update : [];

                return [
                    'prize_type' => trim((string) ($row['prize_type'] ?? '')),
                    'prize_numbers' => array_values(array_map(
                        fn (mixed $number): string => trim((string) $number),
                        is_array($row['prize_numbers'] ?? null) ? $row['prize_numbers'] : [],
                    )),
                ];
            }, $payload['prize_number_updates']), fn (array $update): bool => $update['prize_type'] !== '' && $update['prize_numbers'] !== []));
        }

        if (array_key_exists('payout_amount_updates', $payload) && is_array($payload['payout_amount_updates'])) {
            $normalized['payout_amount_updates'] = array_values(array_filter(array_map(function (mixed $update): array {
                $row = is_array($update) ? $update : [];

                return [
                    'prize_type' => trim((string) ($row['prize_type'] ?? '')),
                    'amount' => $this->moneyAmount($row['amount'] ?? null, 0),
                    'currency' => $this->moneyCurrency($row['amount'] ?? null),
                ];
            }, $payload['payout_amount_updates']), fn (array $update): bool => $update['prize_type'] !== ''));
        }

        return $normalized;
    }

    /**
     * @param array<string, mixed> $payload
     * @return array<string, mixed>
     */
    private function normalizeLiveIngestPayload(array $payload): array
    {
        $prizes = array_map(function (mixed $prize): array {
            $row = is_array($prize) ? $prize : [];

            return [
                'prize_type' => trim((string) ($row['prize_type'] ?? '')),
                'prize_numbers' => array_values(array_map(
                    fn (mixed $number): string => strtolower(trim((string) $number)),
                    is_array($row['prize_numbers'] ?? null) ? $row['prize_numbers'] : [],
                )),
            ];
        }, is_array($payload['prizes'] ?? null) ? $payload['prizes'] : []);

        return [
            'source' => 'sanook',
            'draw_code' => trim((string) ($payload['draw_code'] ?? '')),
            'draw_date' => trim((string) ($payload['draw_date'] ?? '')),
            'scraped_at' => trim((string) ($payload['scraped_at'] ?? now()->toISOString())),
            'completion_percent' => max(0, min(100, (float) ($payload['completion_percent'] ?? $this->completionPercentForLivePrizes($prizes)))),
            'payload_hash' => trim((string) ($payload['payload_hash'] ?? '')),
            'prizes' => $prizes,
        ];
    }

    /**
     * @param array<int, array{prize_type: string, prize_numbers: array<int, string>}> $prizes
     */
    private function completionPercentForLivePrizes(array $prizes): float
    {
        $rules = ThaiGovernmentLotteryRewardTemplate::rules();
        $total = array_sum(array_map(fn (array $rule): int => $rule['count'], $rules));
        $completed = 0;

        foreach ($prizes as $prize) {
            $rule = $rules[$prize['prize_type']] ?? null;

            if ($rule === null) {
                continue;
            }

            foreach ($prize['prize_numbers'] as $number) {
                if (! $this->isPlaceholderNumber($number, $rule['digits'])) {
                    $completed++;
                }
            }
        }

        return $total <= 0 ? 0 : round(($completed / $total) * 100, 2);
    }

    private function createDraftRewardResultForGame(string $gameId): object
    {
        $now = now();
        $rewardResultId = 'rew_'.Str::ulid()->toBase32();

        RewardResult::query()->insert([
            'id' => $rewardResultId,
            'game_id' => $gameId,
            'status' => 'draft',
            'version' => 1,
            'summary_json' => null,
            'created_by_admin_id' => null,
            'created_at' => $now,
            'updated_at' => $now,
        ]);

        $this->ensureDraftRewardPrizes($rewardResultId, $gameId);

        return RewardResult::query()->where('id', $rewardResultId)->first();
    }

    private function ensureDraftRewardPrizes(string $rewardResultId, string $gameId): void
    {
        if (RewardPrize::query()->where('reward_result_id', $rewardResultId)->exists()) {
            return;
        }

        $now = now();
        $rows = [];

        foreach (ThaiGovernmentLotteryRewardTemplate::draftPrizes() as $index => $prize) {
            $rows[] = [
                'id' => 'rpr_'.Str::ulid()->toBase32(),
                'reward_result_id' => $rewardResultId,
                'game_id' => $gameId,
                'prize_type' => $prize['prize_type'],
                'prize_number' => $prize['prize_number'],
                'amount' => $prize['amount']['amount'],
                'currency' => $prize['amount']['currency'],
                'sort_order' => $index,
                'created_at' => $now,
                'updated_at' => $now,
            ];
        }

        RewardPrize::query()->insert($rows);
    }

    /**
     * @param array<int, array{prize_type: string, prize_numbers: array<int, string>}> $prizes
     */
    private function applyLivePrizeUpdates(string $rewardResultId, array $prizes): void
    {
        $rules = ThaiGovernmentLotteryRewardTemplate::rules();

        foreach ($prizes as $prize) {
            $type = $prize['prize_type'];
            $rule = $rules[$type] ?? null;

            if ($rule === null) {
                continue;
            }

            $rows = RewardPrize::query()
                ->where('reward_result_id', $rewardResultId)
                ->where('prize_type', $type)
                ->orderBy('sort_order')
                ->get(['id', 'prize_number'])
                ->all();

            foreach ($prize['prize_numbers'] as $index => $number) {
                if (! isset($rows[$index]) || $this->isPlaceholderNumber($number, $rule['digits'])) {
                    continue;
                }

                if ((string) $rows[$index]->prize_number === $number) {
                    continue;
                }

                RewardPrize::query()->where('id', $rows[$index]->id)->update([
                    'prize_number' => $number,
                    'updated_at' => now(),
                ]);
            }
        }
    }

    /**
     * @return array<string, mixed>
     */
    private function liveWinnerEstimateSummary(string $rewardResultId, string $gameId): array
    {
        $prizes = $this->completedRewardPrizes($rewardResultId);
        $matchedTicketCounts = [];
        $estimatedRows = 0;
        $estimatedPayout = 0;
        $byPrizeType = [];

        foreach ($prizes as $prize) {
            $matches = 0;
            $amount = (int) $prize->amount;

            foreach ($this->ticketPrizeAggregateRows($gameId, $prize)->get()->all() as $match) {
                $ticketCount = (int) $match->ticket_count;
                if ($ticketCount < 1) {
                    continue;
                }

                $countKey = (string) $match->full_number.':'.(string) $match->tenant_id;
                $matchedTicketCounts[$countKey] = max((int) ($matchedTicketCounts[$countKey] ?? 0), $ticketCount);
                $matches += $ticketCount;
                $estimatedRows += $ticketCount;
                $estimatedPayout += $ticketCount * $amount;
            }

            if ($matches > 0) {
                $type = (string) $prize->prize_type;
                $byPrizeType[$type] = ($byPrizeType[$type] ?? 0) + $matches;
            }
        }

        return [
            'mode' => 'live_result',
            'completed_prize_count' => count($prizes),
            'estimated_winning_ticket_count' => array_sum($matchedTicketCounts),
            'estimated_winning_rows' => $estimatedRows,
            'estimated_payout_amount' => $this->money($estimatedPayout),
            'by_prize_type' => $byPrizeType,
            'official_claimable' => false,
        ];
    }

    /**
     * @return array<string, mixed>
     */
    private function rewardResultResource(object $result): array
    {
        return [
            'id' => (string) $result->id,
            'game_id' => (string) $result->game_id,
            'status' => (string) $result->status,
            'version' => (int) $result->version,
            'prizes' => array_map(fn (object $prize): array => $this->prizeResource($prize), RewardPrize::query()->where('reward_result_id', $result->id)->orderBy('sort_order')->get()->all()),
            'summary' => $this->decodeJsonObject($result->summary_json),
            'checked_at' => $result->checked_at,
            'verified_at' => $result->verified_at,
            'published_at' => $result->published_at,
        ];
    }

    private function prizeResource(object $prize): array
    {
        return [
            'prize_type' => (string) $prize->prize_type,
            'prize_number' => (string) $prize->prize_number,
            'amount' => $this->money($this->normalizedRewardPrizeAmount($prize), (string) $prize->currency),
        ];
    }

    /**
     * @return array<string, mixed>
     */
    private function summary(string $rewardResultId): array
    {
        $result = RewardResult::where('id', $rewardResultId)->first();
        $prizes = RewardPrize::query()->where('reward_result_id', $rewardResultId)->orderBy('sort_order')->get()->all();

        return [
            'reward_result_id' => (string) $result->id,
            'game_id' => (string) $result->game_id,
            'reward_version' => (int) $result->version,
            'status' => (string) $result->status,
            'prizes' => array_map(function (object $prize): array {
                $winningCount = WinningTicket::where('reward_prize_id', $prize->id)->count();

                $amount = $this->normalizedRewardPrizeAmount($prize);

                return $this->prizeResource($prize) + [
                    'winning_count' => $winningCount,
                    'total_amount' => $this->money($winningCount * $amount, (string) $prize->currency),
                ];
            }, $prizes),
            'winning_count' => WinningTicket::where('reward_result_id', $rewardResultId)->count(),
            'checked_ticket_count' => RewardCheckBatch::where('reward_result_id', $rewardResultId)->sum('processed_ticket_count'),
        ];
    }

    /**
     * @return array{body: array<string, mixed>|null, etag: string|null}
     */
    private function publicResultEnvelope(?object $result): array
    {
        if ($result === null) {
            return ['body' => null, 'etag' => null];
        }

        $body = $this->publicSummary($result);

        return [
            'body' => $body,
            'etag' => '"reward-'.$body['game_id'].'-v'.$body['reward_version'].'"',
        ];
    }

    /**
     * @return array<string, mixed>
     */
    private function publicSummary(object $result): array
    {
        $summary = $this->decodeJsonObject($result->summary_json);
        $game = Game::whereKey($result->game_id)->first(['code', 'name', 'draw_at']);

        return [
            'game_id' => (string) $result->game_id,
            'game_code' => (string) ($game?->code ?? ''),
            'draw_code' => (string) ($game?->code ?? ($summary['source']['draw_code'] ?? '')),
            'game_name' => (string) ($game?->name ?? ($summary['game_name'] ?? '')),
            'draw_at' => $game?->draw_at,
            'reward_version' => (int) $result->version,
            'status' => (string) $result->status,
            'prizes' => $summary['prizes'] ?? array_map(fn (object $prize): array => $this->prizeResource($prize), RewardPrize::query()->where('reward_result_id', $result->id)->orderBy('sort_order')->get()->all()),
        ];
    }

    /**
     * @return array{body: array<string, mixed>|null, etag: string|null}
     */
    private function publicLiveResultEnvelope(?object $result): array
    {
        if ($result === null) {
            return ['body' => null, 'etag' => null];
        }

        $body = $this->publicLiveSummary($result);
        $payloadHash = (string) ($body['source']['payload_hash'] ?? sha1((string) $result->id.'|'.(string) $result->status.'|'.(string) $result->updated_at));

        return [
            'body' => $body,
            'etag' => '"reward-live-'.$body['game_id'].'-'.substr($payloadHash, 0, 16).'"',
        ];
    }

    /**
     * @return array<string, mixed>
     */
    private function publicLiveSummary(object $result): array
    {
        $summary = $this->decodeJsonObject($result->summary_json);
        $game = Game::whereKey($result->game_id)->first(['code', 'name', 'draw_at']);
        $prizes = RewardPrize::query()
            ->where('reward_result_id', $result->id)
            ->orderBy('sort_order')
            ->get()
            ->all();

        return [
            'reward_result_id' => (string) $result->id,
            'game_id' => (string) $result->game_id,
            'game_code' => (string) ($game?->code ?? ''),
            'draw_code' => (string) ($game?->code ?? ($summary['source']['draw_code'] ?? '')),
            'game_name' => (string) ($game?->name ?? ''),
            'draw_at' => $game?->draw_at,
            'reward_version' => (int) $result->version,
            'status' => match ((string) $result->status) {
                'draft' => 'live_draft',
                'published' => 'published',
                default => 'live_unconfirmed',
            },
            'official_status' => (string) $result->status,
            'completion_percent' => (float) ($summary['live']['completion_percent'] ?? $this->completionPercentForPrizeRows($prizes)),
            'source' => $summary['source'] ?? ['name' => 'central', 'mode' => 'unconfirmed'],
            'live_estimate' => $summary['live_estimate'] ?? $this->liveWinnerEstimateSummary((string) $result->id, (string) $result->game_id),
            'prizes' => array_map(fn (object $prize): array => $this->livePrizeResource($prize), $prizes),
            'updated_at' => $summary['live']['updated_at'] ?? $result->updated_at,
        ];
    }

    private function livePrizeResource(object $prize): array
    {
        $type = (string) $prize->prize_type;
        $number = (string) $prize->prize_number;

        if ($this->isPendingPrizeNumber($number)) {
            $number = $this->placeholderForPrizeType($type);
        }

        return [
            'prize_type' => $type,
            'prize_number' => $number,
            'amount' => $this->money((int) $prize->amount, (string) $prize->currency),
            'is_pending' => $this->isPlaceholderNumber($number, strlen($number)),
        ];
    }

    /**
     * @param array<string, mixed> $resource
     * @return array<string, mixed>
     */
    private function compactLiveBroadcastPayload(array $resource): array
    {
        $highlightTypes = ['first_prize', 'front3', 'back3', 'back2', 'near_first_prize'];

        return [
            'reward_result_id' => $resource['reward_result_id'] ?? null,
            'game_id' => $resource['game_id'] ?? null,
            'game_code' => $resource['game_code'] ?? null,
            'draw_code' => $resource['draw_code'] ?? null,
            'game_name' => $resource['game_name'] ?? null,
            'status' => $resource['status'] ?? 'live_draft',
            'official_status' => $resource['official_status'] ?? 'draft',
            'completion_percent' => $resource['completion_percent'] ?? 0,
            'source' => $resource['source'] ?? ['name' => 'sanook'],
            'live_estimate' => $resource['live_estimate'] ?? ['mode' => 'live_result', 'official_claimable' => false],
            'prizes' => array_values(array_filter(
                is_array($resource['prizes'] ?? null) ? $resource['prizes'] : [],
                fn (array $prize): bool => in_array((string) ($prize['prize_type'] ?? ''), $highlightTypes, true),
            )),
            'updated_at' => $resource['updated_at'] ?? now()->toISOString(),
            'refresh_required' => true,
        ];
    }

    private function broadcastRewardLiveUpdate(string $rewardResultId, bool $changed = true): void
    {
        $result = RewardResult::query()->whereKey($rewardResultId)->first();

        if ($result === null) {
            return;
        }

        if (! in_array((string) $result->status, self::PUBLIC_LIVE_RESULT_STATUSES, true)) {
            return;
        }

        $payload = $this->compactLiveBroadcastPayload($this->publicLiveSummary($result)) + [
            'event_type' => 'reward.result.live.updated',
            'changed' => $changed,
        ];

        DB::afterCommit(fn () => RewardLiveResultUpdated::dispatch($payload));
    }

    /**
     * @param array<int, object> $prizes
     */
    private function completionPercentForPrizeRows(array $prizes): float
    {
        if ($prizes === []) {
            return 0;
        }

        $completed = count(array_filter($prizes, fn (object $prize): bool => ! $this->isPendingPrizeNumber((string) $prize->prize_number)));

        return round(($completed / count($prizes)) * 100, 2);
    }

    private function placeholderForPrizeType(string $type): string
    {
        $digits = ThaiGovernmentLotteryRewardTemplate::rules()[$type]['digits'] ?? 6;

        return str_repeat('x', $digits);
    }

    private function normalizePrizeNumberUpdateValue(string $type, int $index, mixed $number): string
    {
        $normalized = trim((string) $number);

        return $this->isPendingPrizeNumber($normalized)
            ? ThaiGovernmentLotteryRewardTemplate::pendingNumber($type, $index + 1)
            : $normalized;
    }

    private function isPendingPrizeNumber(string $number): bool
    {
        return $number === '' || str_starts_with($number, 'pending_') || preg_match('/^x+$/i', $number) === 1;
    }

    private function isPlaceholderNumber(string $number, int $digits): bool
    {
        return preg_match('/^x{'.$digits.'}$/i', trim($number)) === 1;
    }

    /**
     * @param array<int, object> $rows
     * @return array<string, mixed>
     */
    private function claimListResponse(array $rows, int $limit): array
    {
        $hasMore = count($rows) > $limit;
        $rows = array_slice($rows, 0, $limit);

        return [
            'data' => array_map(fn (object $claim): array => $this->claimResource($claim), $rows),
            'meta' => [
                'next_cursor' => $hasMore && $rows !== [] ? (string) end($rows)->id : null,
                'has_more' => $hasMore,
            ],
        ];
    }

    /**
     * @return array<int, object>
     */
    private function ticketWinningRows(string $tenantId, string $ticketId): array
    {
        $rows = WinningTicket::query()
            ->join('reward_results', 'reward_results.id', '=', 'winning_tickets.reward_result_id')
            ->where('winning_tickets.tenant_id', $tenantId)
            ->where('winning_tickets.ticket_id', $ticketId)
            ->select('winning_tickets.*', 'reward_results.status as reward_result_status')
            ->get()
            ->all();

        return $this->sortWinningRows($rows);
    }

    /**
     * @param array<int, object> $rows
     * @return array<int, object>
     */
    private function sortWinningRows(array $rows): array
    {
        usort($rows, function (object $left, object $right): int {
            $leftOrder = self::PRIZE_TYPE_SORT_ORDER[(string) $left->prize_type] ?? 999;
            $rightOrder = self::PRIZE_TYPE_SORT_ORDER[(string) $right->prize_type] ?? 999;

            return ($leftOrder <=> $rightOrder)
                ?: ((int) $right->amount <=> (int) $left->amount)
                ?: strcmp((string) $left->id, (string) $right->id);
        });

        return $rows;
    }

    /**
     * @param array<int, object> $rows
     */
    private function sumWinningAmount(array $rows, string $field = 'amount', ?string $fallbackField = null): int
    {
        return array_reduce($rows, function (int $total, object $row) use ($field, $fallbackField): int {
            $value = $row->{$field} ?? ($fallbackField === null ? 0 : ($row->{$fallbackField} ?? 0));

            return $total + $this->normalizedWinningAmount($row, $field, $fallbackField, (int) $value);
        }, 0);
    }

    private function normalizedWinningAmount(object $winning, string $field = 'amount', ?string $fallbackField = null, ?int $rawAmount = null): int
    {
        $amount = $rawAmount ?? (int) ($winning->{$field} ?? ($fallbackField === null ? 0 : ($winning->{$fallbackField} ?? 0)));

        if ($field === 'adjustment_amount') {
            return $amount;
        }

        if (($winning->tenant_price_rule_id ?? null) !== null) {
            return $amount;
        }

        return ThaiGovernmentLotteryRewardTemplate::normalizeStoredMinorAmount(
            (string) ($winning->prize_type ?? ''),
            $amount,
            (string) ($winning->currency ?? ThaiGovernmentLotteryRewardTemplate::CURRENCY),
        );
    }

    private function normalizedRewardPrizeAmount(object $prize): int
    {
        return ThaiGovernmentLotteryRewardTemplate::normalizeStoredMinorAmount(
            (string) ($prize->prize_type ?? ''),
            (int) ($prize->amount ?? 0),
            (string) ($prize->currency ?? ThaiGovernmentLotteryRewardTemplate::CURRENCY),
        );
    }

    /**
     * @param array<int, object> $rows
     * @return array<int, array<string, mixed>>
     */
    private function winningPrizeRowsResource(array $rows): array
    {
        return array_map(fn (object $winning): array => [
            'winning_ticket_id' => (string) $winning->id,
            'reward_result_id' => (string) $winning->reward_result_id,
            'reward_prize_id' => (string) $winning->reward_prize_id,
            'prize_type' => (string) $winning->prize_type,
            'prize_number' => (string) $winning->prize_number,
            'amount' => $this->money($this->normalizedWinningAmount($winning, 'amount'), (string) $winning->currency),
            'base_amount' => $this->money($this->normalizedWinningAmount($winning, 'base_amount', 'amount'), (string) $winning->currency),
            'adjustment_amount' => $this->money((int) ($winning->adjustment_amount ?? 0), (string) $winning->currency),
            'currency' => (string) $winning->currency,
            'status' => (string) $winning->status,
        ], $rows);
    }

    /**
     * @return array<string, mixed>
     */
    private function claimResource(object $claim): array
    {
        $ticket = Ticket::where('id', $claim->ticket_id)->first();
        $customer = Customer::where('id', $claim->customer_id)->first();
        $winnings = $this->ticketWinningRows((string) $claim->tenant_id, (string) $claim->ticket_id);
        $winning = $winnings[0] ?? WinningTicket::where('id', $claim->winning_ticket_id)->first();
        $wallet = $claim->wallet_id === null ? null : Wallet::where('id', $claim->wallet_id)->first();
        $effectivePrizeAmount = $this->claimEffectivePrizeAmount($claim, $winnings);
        $basePrizeAmount = $this->claimBasePrizeAmount($claim, $winnings);
        $adjustmentAmount = $this->claimAdjustmentAmount($claim, $winnings);

        return [
            'id' => (string) $claim->id,
            'tenant_id' => (string) $claim->tenant_id,
            'reference' => $claim->reference,
            'customer' => $customer === null ? null : $this->customerProfile($customer),
            'ticket' => $ticket === null ? null : $this->ticketResource($ticket),
            'winning_ticket_id' => (string) $claim->winning_ticket_id,
            'game_id' => (string) $claim->game_id,
            'prize_type' => $winning?->prize_type,
            'prize_number' => $winning?->prize_number,
            'prize_amount' => $this->money($effectivePrizeAmount, (string) $claim->currency),
            'prizes' => $this->winningPrizeRowsResource($winnings),
            'prize_count' => count($winnings),
            'reward_pricing' => [
                'base_source' => TenantRewardPriceRuleService::BASE_SOURCE_CENTRAL_REWARD,
                'base_prize_amount' => $this->money($basePrizeAmount, (string) $claim->currency),
                'adjustment_amount' => $this->money($adjustmentAmount, (string) $claim->currency),
                'effective_prize_amount' => $this->money($effectivePrizeAmount, (string) $claim->currency),
                'tenant_price_rule_id' => $claim->tenant_price_rule_id,
                'price_rule_snapshot' => $this->decodeJsonObject($claim->price_rule_snapshot_json),
            ],
            'status' => (string) $claim->status,
            'payout_method' => $claim->payout_method,
            'bank_account' => $this->decodeJsonObject($claim->bank_account_json),
            'payout_wallet' => $wallet === null ? null : $this->walletResource($wallet),
            'submitted_at' => $claim->submitted_at,
            'reviewed_at' => $claim->reviewed_at,
            'paid_at' => $claim->paid_at,
            'admin_note' => $claim->admin_note,
            'created_at' => $claim->created_at,
        ];
    }

    /**
     * @param array<int, object>|null $winnings
     */
    private function claimEffectivePrizeAmount(object $claim, ?array $winnings = null): int
    {
        $winnings ??= $this->ticketWinningRows((string) $claim->tenant_id, (string) $claim->ticket_id);
        $amount = $this->sumWinningAmount($winnings, 'amount');

        return $amount > 0 ? $amount : (int) $claim->prize_amount;
    }

    /**
     * @param array<int, object>|null $winnings
     */
    private function claimBasePrizeAmount(object $claim, ?array $winnings = null): int
    {
        $winnings ??= $this->ticketWinningRows((string) $claim->tenant_id, (string) $claim->ticket_id);
        $amount = $this->sumWinningAmount($winnings, 'base_amount', 'amount');

        return $amount > 0 ? $amount : (int) ($claim->base_prize_amount ?? $claim->prize_amount);
    }

    /**
     * @param array<int, object>|null $winnings
     */
    private function claimAdjustmentAmount(object $claim, ?array $winnings = null): int
    {
        $winnings ??= $this->ticketWinningRows((string) $claim->tenant_id, (string) $claim->ticket_id);

        if ($winnings !== []) {
            return $this->sumWinningAmount($winnings, 'adjustment_amount');
        }

        return (int) ($claim->adjustment_amount ?? 0);
    }

    private function ticketMatchesPrize(string $fullNumber, object $prize): bool
    {
        $type = strtolower((string) $prize->prize_type);
        $number = (string) $prize->prize_number;

        if (str_contains($type, 'front3')) {
            return substr($fullNumber, 0, 3) === $number;
        }

        if (str_contains($type, 'back3')) {
            return substr($fullNumber, -3) === $number;
        }

        if (str_contains($type, 'back2')) {
            return substr($fullNumber, -2) === $number;
        }

        return $fullNumber === $number;
    }

    private function setGameStatus(string $gameId, string $status): void
    {
        $now = now();

        Game::query()->whereKey($gameId)->update([
            'status' => $status,
            'updated_at' => $now,
        ]);

        if (in_array($status, self::CLOSED_GAME_STATUSES, true)) {
            Game::query()
                ->whereKey($gameId)
                ->whereNull('closed_at')
                ->update(['closed_at' => $now]);
        }
    }

    private function centralWaitingResultYoutubeUrl(): string
    {
        $value = PlatformSystemSetting::query()
            ->where('key', 'waiting_result_youtube_url')
            ->where('status', 'active')
            ->first()
            ?->value_json;

        return is_string($value) ? trim($value) : '';
    }

    /**
     * @param array<string, mixed> $payload
     */
    private function liveSettingsPayloadValue(array $payload): ?string
    {
        $settings = is_array($payload['settings'] ?? null) ? $payload['settings'] : [];
        $live = is_array($payload['live'] ?? null) ? $payload['live'] : [];

        foreach (['waiting_result_youtube_url', 'youtube_live_url'] as $key) {
            if (array_key_exists($key, $settings)) {
                return is_scalar($settings[$key]) || $settings[$key] === null ? (string) ($settings[$key] ?? '') : null;
            }

            if (array_key_exists($key, $live)) {
                return is_scalar($live[$key]) || $live[$key] === null ? (string) ($live[$key] ?? '') : null;
            }

            if (array_key_exists($key, $payload)) {
                return is_scalar($payload[$key]) || $payload[$key] === null ? (string) ($payload[$key] ?? '') : null;
            }
        }

        return null;
    }

    /**
     * @param array<string, mixed> $payload
     */
    private function auditAdmin(AdminSessionContext $actor, Request $request, string $action, string $targetType, ?string $targetId, array $payload, ?string $tenantId = null): void
    {
        $this->auditLogger->logAdminWrite(
            actorId: $actor->adminUser['id'],
            scopeType: $actor->activeScope(),
            action: $action,
            targetType: $targetType,
            targetId: $targetId,
            payload: [
                'idempotency_key' => $request->header('Idempotency-Key'),
                'payload' => $payload,
            ],
            tenantId: $tenantId,
            requestId: $request->header('X-Request-Id'),
            ipAddress: $request->ip(),
            userAgent: $request->userAgent(),
        );
    }

    /**
     * @param array{id: string, wallet_id: string, balance_after: int} $ledger
     */
    private function insertWalletOutbox(string $tenantId, string $customerId, string $walletId, array $ledger, ?string $idempotencyKey, ?string $correlationId): void
    {
        $this->insertOutboxEvent('wallet.updated.v1', null, 'wallet', $walletId, $idempotencyKey, $correlationId, [
            'tenant_id' => $tenantId,
            'customer_id' => $customerId,
            'wallet_id' => $walletId,
            'ledger_id' => $ledger['id'],
            'entry_type' => 'credit',
            'amount' => null,
            'currency' => 'THB',
            'posted_balance' => $ledger['balance_after'],
        ], $tenantId);
    }

    /**
     * @param array<string, mixed> $payload
     */
    private function insertOutboxEvent(string $eventType, ?string $gameId, string $aggregateType, string $aggregateId, ?string $idempotencyKey, ?string $correlationId, array $payload, ?string $tenantId = null): void
    {
        $eventId = 'evt_'.Str::ulid()->toBase32();
        $now = now();

        SyncOutbox::query()->insert([
            'id' => $eventId,
            'event_id' => $eventId,
            'event_type' => $eventType,
            'event_version' => 1,
            'producer' => 'reward_engine',
            'tenant_id' => $tenantId,
            'partner_id' => null,
            'game_id' => $gameId,
            'aggregate_type' => $aggregateType,
            'aggregate_id' => $aggregateId,
            'idempotency_key' => $idempotencyKey,
            'correlation_id' => $correlationId,
            'payload_json' => json_encode($payload, JSON_THROW_ON_ERROR),
            'status' => 'pending',
            'attempt_count' => 0,
            'available_at' => $now,
            'processed_at' => null,
            'last_error' => null,
            'created_at' => $now,
            'updated_at' => $now,
        ]);
    }

    private function claimStatusForTicket(object $claim): string
    {
        $claimStatus = strtolower((string) $claim->status);

        if ($claimStatus === 'approved' && ($claim->paid_at !== null || $claim->payout_ledger_id !== null || (string) $claim->payout_method === 'bank_transfer')) {
            return 'paid_out';
        }

        return match ($claimStatus) {
            'submitted', 'under_review' => 'claim_submitted',
            'approved' => 'approved',
            'paid', 'paid_out' => 'paid_out',
            'rejected' => 'rejected',
            'cancelled' => 'cancelled',
            default => 'pending_result',
        };
    }

    /**
     * @param array<int, object> $rows
     * @return array<int, object>
     */
    private function claimableWinningRows(array $rows): array
    {
        return array_values(array_filter(
            $rows,
            fn (object $row): bool => (string) $row->reward_result_status === 'published' && in_array((string) $row->status, ['pending', 'verified'], true),
        ));
    }

    private function createAutomaticRewardClaimsForResult(string $rewardResultId, mixed $submittedAt): void
    {
        if (! Schema::hasColumn('customers', 'auto_reward_claim_enabled') || ! Schema::hasColumn('customers', 'auto_reward_claim_payout_method')) {
            return;
        }

        $rows = WinningTicket::query()
            ->join('tickets', function ($join): void {
                $join->on('tickets.id', '=', 'winning_tickets.ticket_id')
                    ->on('tickets.tenant_id', '=', 'winning_tickets.tenant_id');
            })
            ->join('customers', function ($join): void {
                $join->on('customers.id', '=', 'tickets.customer_id')
                    ->on('customers.tenant_id', '=', 'tickets.tenant_id');
            })
            ->where('winning_tickets.reward_result_id', $rewardResultId)
            ->where('customers.auto_reward_claim_enabled', true)
            ->whereIn('winning_tickets.status', ['pending', 'verified'])
            ->select(
                'winning_tickets.*',
                'tickets.customer_id as ticket_customer_id',
                'customers.auto_reward_claim_payout_method',
                'customers.reward_payout_bank_account_json',
            )
            ->orderBy('winning_tickets.tenant_id')
            ->orderBy('winning_tickets.ticket_id')
            ->orderBy('winning_tickets.id')
            ->get()
            ->all();

        if ($rows === []) {
            return;
        }

        $grouped = [];

        foreach ($rows as $row) {
            $key = (string) $row->tenant_id.':'.(string) $row->ticket_id;
            $grouped[$key][] = $row;
        }

        foreach ($grouped as $ticketRows) {
            $ticketRows = $this->sortWinningRows($ticketRows);
            $winning = $ticketRows[0] ?? null;

            if ($winning === null) {
                continue;
            }

            $tenantId = (string) $winning->tenant_id;
            $ticketId = (string) $winning->ticket_id;
            $customerId = (string) $winning->ticket_customer_id;

            if ($customerId === '' || RewardClaim::where('tenant_id', $tenantId)->where('ticket_id', $ticketId)->whereNotIn('status', ['rejected', 'cancelled'])->exists()) {
                continue;
            }

            $payoutMethod = $this->normalizeAutomaticRewardPayoutMethod($winning->auto_reward_claim_payout_method ?? null);
            $bankAccount = [];
            $walletId = null;

            if ($payoutMethod === 'bank_transfer') {
                $bankAccount = $this->decodeJsonObject($winning->reward_payout_bank_account_json ?? null);

                if (! $this->hasUsableBankAccount($bankAccount)) {
                    continue;
                }
            } else {
                $walletId = $this->customerAuth->ensurePrimaryWallet($tenantId, $customerId);
            }

            $claimId = 'rcl_'.Str::ulid()->toBase32();
            $priceRuleSnapshot = $winning->price_rule_snapshot_json;
            $priceRuleSnapshotJson = is_array($priceRuleSnapshot) ? json_encode($priceRuleSnapshot, JSON_THROW_ON_ERROR) : $priceRuleSnapshot;
            $normalized = [
                'source' => 'auto_reward_claim',
                'reward_result_id' => $rewardResultId,
                'ticket_id' => $ticketId,
                'payout_method' => $payoutMethod,
            ];

            RewardClaim::query()->insert([
                'id' => $claimId,
                'tenant_id' => $tenantId,
                'customer_id' => $customerId,
                'ticket_id' => $ticketId,
                'winning_ticket_id' => (string) $winning->id,
                'game_id' => (string) $winning->game_id,
                'wallet_id' => $walletId,
                'payout_ledger_id' => null,
                'reference' => 'RWD-'.strtoupper(substr($claimId, -10)),
                'status' => 'submitted',
                'payout_method' => $payoutMethod,
                'prize_amount' => $this->sumWinningAmount($ticketRows, 'amount'),
                'base_prize_amount' => $this->sumWinningAmount($ticketRows, 'base_amount', 'amount'),
                'adjustment_amount' => $this->sumWinningAmount($ticketRows, 'adjustment_amount'),
                'tenant_price_rule_id' => $winning->tenant_price_rule_id,
                'price_rule_snapshot_json' => $priceRuleSnapshotJson,
                'currency' => (string) $winning->currency,
                'bank_account_json' => $bankAccount === [] ? null : json_encode($bankAccount, JSON_THROW_ON_ERROR),
                'customer_note' => null,
                'admin_note' => null,
                'idempotency_key' => null,
                'payload_hash' => $this->idempotency->payloadHash($normalized),
                'reviewed_by_admin_id' => null,
                'paid_by_admin_id' => null,
                'submitted_at' => $submittedAt,
                'reviewed_at' => null,
                'paid_at' => null,
                'created_at' => $submittedAt,
                'updated_at' => $submittedAt,
            ]);

            $this->queueRewardClaimUpdatedBroadcast($tenantId, $claimId);
        }
    }

    private function normalizeAutomaticRewardPayoutMethod(mixed $value): string
    {
        return trim((string) $value) === 'bank_transfer' ? 'bank_transfer' : 'wallet_credit';
    }

    private function queueRewardClaimUpdatedBroadcast(string $tenantId, string $claimId): void
    {
        DB::afterCommit(function () use ($tenantId, $claimId): void {
            $claim = RewardClaim::query()
                ->forTenant($tenantId)
                ->where('id', $claimId)
                ->first();

            if ($claim === null) {
                return;
            }

            RewardClaimUpdated::dispatch([
                'event_type' => 'reward.claim.updated',
                'tenant_id' => $tenantId,
                'claim_id' => $claimId,
                'claim' => $this->claimResource($claim),
                'updated_at' => now()->toISOString(),
            ]);
            AdminMenuBadgesUpdated::dispatch('tenant', $tenantId, 'exchange_reward');
        });
    }

    private function customerProfile(object $customer): array
    {
        return [
            'id' => (string) $customer->id,
            'tenant_id' => (string) $customer->tenant_id,
            'customer_no' => CustomerNo::display($customer->customer_no ?? null, (string) $customer->id),
            'member_no' => CustomerNo::display($customer->customer_no ?? null, (string) $customer->id),
            'name' => $customer->name,
            'phone' => $customer->phone,
            'email' => $customer->email ?? null,
            'status' => $customer->status ?? null,
            'avatar_url' => $customer->avatar_url ?? null,
        ];
    }

    private function ticketResource(object $ticket): array
    {
        $game = Game::whereKey($ticket->game_id)->first(['id', 'code', 'name', 'draw_at', 'status']);

        return [
            'id' => (string) $ticket->id,
            'game_id' => (string) $ticket->game_id,
            'full_number' => (string) $ticket->full_number,
            'status' => (string) $ticket->status,
            'image_thumb_url' => PublicUrl::normalizeAssetUrl($ticket->image_thumb_url),
            'image_url' => PublicUrl::normalizeAssetUrl($ticket->image_url),
            'game' => $game === null ? null : [
                'id' => (string) $game->id,
                'code' => (string) $game->code,
                'name' => (string) $game->name,
                'draw_at' => $game->draw_at,
                'status' => (string) $game->status,
            ],
        ];
    }

    private function walletResource(object $wallet): array
    {
        return [
            'id' => (string) $wallet->id,
            'name' => (string) $wallet->name,
            'type' => (string) $wallet->type,
            'balance' => $this->money((int) $wallet->balance_amount, (string) $wallet->currency),
        ];
    }

    private function money(int $amount, string $currency = 'THB'): array
    {
        return ['amount' => $amount, 'currency' => $currency];
    }

    private function moneyAmount(mixed $value, int $default): int
    {
        if (is_array($value) && isset($value['amount'])) {
            return (int) $value['amount'];
        }

        if (is_numeric($value)) {
            return (int) $value;
        }

        return $default;
    }

    private function moneyCurrency(mixed $value): string
    {
        return is_array($value) && isset($value['currency']) ? (string) $value['currency'] : 'THB';
    }

    /**
     * @param array<string, mixed> $payload
     */
    private function hasRewardUpdatePayload(array $payload): bool
    {
        return array_key_exists('prizes', $payload)
            || array_key_exists('prize_number_updates', $payload)
            || array_key_exists('payout_amount_updates', $payload);
    }

    /**
     * @param array<string, mixed> $payload
     */
    private function hasResultRecordingPayload(array $payload): bool
    {
        return array_key_exists('prizes', $payload)
            || array_key_exists('prize_number_updates', $payload);
    }

    /**
     * @param array<string, array<int, string>> $base
     * @param array<string, array<int, string>> $incoming
     * @return array<string, array<int, string>>
     */
    private function mergeFieldErrors(array $base, array $incoming): array
    {
        foreach ($incoming as $field => $messages) {
            $base[$field] = array_values(array_merge($base[$field] ?? [], $messages));
        }

        return $base;
    }

    /**
     * @param array<string, mixed> $claim
     * @return array<string, mixed>
     */
    private function lineClaimVariables(string $tenantId, array $claim, string $statusLabel): array
    {
        $customer = is_array($claim['customer'] ?? null) ? $claim['customer'] : [];
        $amount = $claim['prize_amount']['amount'] ?? $claim['claim_amount']['amount'] ?? 0;
        $reason = trim((string) ($claim['admin_note'] ?? ''));

        return [
            'event' => ['title' => 'แจ้งเตือนการขึ้นเงินรางวัล'],
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

    private function lineRewardClaimStatusLabel(string $status): string
    {
        return match ($status) {
            'approved', 'paid' => 'จ่ายเงินรางวัลแล้ว',
            'rejected' => 'ไม่อนุมัติ',
            'under_review' => 'กำลังตรวจสอบ',
            default => 'รอตรวจสอบ',
        };
    }

    /**
     * @param array<string, mixed> $claim
     * @return array<string, mixed>
     */
    private function telegramClaimVariables(string $tenantId, array $claim, ?string $statusLabel = null, ?array $adminUser = null): array
    {
        $customer = is_array($claim['customer'] ?? null) ? $claim['customer'] : [];
        $amount = (int) ($claim['prize_amount']['amount'] ?? $claim['claim_amount']['amount'] ?? 0);
        $reason = trim((string) ($claim['admin_note'] ?? ''));
        $isStatusUpdate = $statusLabel !== null && $statusLabel !== '';

        return [
            'event' => [
                'title' => $isStatusUpdate ? 'ตรวจสอบรายการขึ้นเงินรางวัลแล้ว' : 'มีรายการขึ้นเงินรางวัลรอตรวจสอบ',
                'occurred_at' => $this->telegramNotifications->occurredAt(
                    $isStatusUpdate
                        ? ($claim['paid_at'] ?? $claim['reviewed_at'] ?? $claim['updated_at'] ?? null)
                        : ($claim['submitted_at'] ?? $claim['created_at'] ?? null),
                ),
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
                'status_label' => $statusLabel ?? 'รอตรวจสอบ',
                'reason' => $reason === '' ? '' : 'เหตุผล: '.$reason,
            ],
        ];
    }

    private function limit(mixed $value): int
    {
        $limit = filter_var($value, FILTER_VALIDATE_INT);

        if ($limit === false) {
            return 50;
        }

        return max(1, min(100, (int) $limit));
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
}
