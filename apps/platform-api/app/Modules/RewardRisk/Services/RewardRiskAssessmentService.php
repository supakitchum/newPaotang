<?php

namespace App\Modules\RewardRisk\Services;

use App\Jobs\EvaluateRewardRiskAssessmentJob;
use App\Models\RewardPrize;
use App\Models\RewardResult;
use App\Models\RewardRiskFinding;
use App\Models\RewardRiskFindingTicket;
use App\Models\RewardRiskRun;
use App\Models\TenantRewardRiskSetting;
use App\Models\Ticket;
use App\Models\WinningTicket;
use App\Modules\Reward\Services\TenantRewardPriceRuleService;
use App\Modules\RewardRisk\Events\RewardRiskAssessmentUpdated;
use App\Shared\Audit\AuditLogger;
use App\Shared\Auth\AdminSessionContext;
use App\Shared\Idempotency\IdempotencyService;
use Illuminate\Database\Eloquent\Builder;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Str;

class RewardRiskAssessmentService
{
    public const PRIZE_TYPES = [
        'first_prize', 'near_first_prize', 'second_prize', 'third_prize',
        'fourth_prize', 'fifth_prize', 'front3', 'back3', 'back2',
    ];

    public function __construct(
        private readonly LotteryPrizeMatcher $matcher,
        private readonly TenantRewardPriceRuleService $rewardPrices,
        private readonly IdempotencyService $idempotency,
        private readonly AuditLogger $audit,
    ) {
    }

    public function validateSettings(array $payload): array
    {
        $errors = [];
        $enabled = filter_var($payload['enabled'] ?? false, FILTER_VALIDATE_BOOL, FILTER_NULL_ON_FAILURE);
        $types = $payload['monitored_prize_types'] ?? null;
        $multiplier = $payload['threshold_multiplier'] ?? null;

        if ($enabled === null) {
            $errors['enabled'][] = 'The enabled field must be true or false.';
        }
        if (! is_array($types)) {
            $errors['monitored_prize_types'][] = 'The monitored_prize_types field must be an array.';
        } else {
            $normalized = array_values(array_unique(array_map(fn ($value): string => trim((string) $value), $types)));
            if ($enabled === true && $normalized === []) {
                $errors['monitored_prize_types'][] = 'Select at least one prize type when assessment is enabled.';
            }
            foreach ($normalized as $type) {
                if (! in_array($type, self::PRIZE_TYPES, true)) {
                    $errors['monitored_prize_types'][] = 'The monitored prize type '.$type.' is invalid.';
                }
            }
        }
        if (! is_numeric($multiplier) || (float) $multiplier < 0.01 || (float) $multiplier > 1000) {
            $errors['threshold_multiplier'][] = 'The threshold_multiplier field must be between 0.01 and 1000.00.';
        }

        return $errors;
    }

    public function settings(string $tenantId): array
    {
        return $this->settingsResource(TenantRewardRiskSetting::query()->where('tenant_id', $tenantId)->first(), $tenantId);
    }

    public function updateSettings(string $tenantId, array $payload, AdminSessionContext $actor, Request $request): array
    {
        $normalized = [
            'enabled' => filter_var($payload['enabled'] ?? false, FILTER_VALIDATE_BOOL),
            'monitored_prize_types' => array_values(array_filter(
                self::PRIZE_TYPES,
                fn (string $type): bool => in_array($type, array_map('strval', $payload['monitored_prize_types'] ?? []), true),
            )),
            'threshold_multiplier' => number_format((float) ($payload['threshold_multiplier'] ?? 1), 2, '.', ''),
        ];
        $idempotencyKey = (string) $request->header('Idempotency-Key');

        $result = DB::transaction(function () use ($tenantId, $normalized, $actor, $request, $idempotencyKey): array {
            $route = 'admin.tenant.reward-risk.settings.put';
            $actorId = (string) $actor->adminUser['id'];
            $replay = $this->idempotency->replayOrConflict($tenantId, 'tenant_admin', $actorId, $route, $idempotencyKey, $normalized, 'reward_risk.manage', true);

            if (is_array($replay)) {
                return ['resource' => $replay['body'] ?? [], 'replayed' => true];
            }
            if ($replay !== null) {
                return ['error' => $replay];
            }

            $existing = TenantRewardRiskSetting::query()->where('tenant_id', $tenantId)->lockForUpdate()->first();
            $setting = $existing ?? new TenantRewardRiskSetting([
                'id' => 'rrs_'.Str::ulid()->toBase32(),
                'tenant_id' => $tenantId,
                'version' => 0,
            ]);
            $setting->fill([
                'enabled' => $normalized['enabled'],
                'monitored_prize_types_json' => $normalized['monitored_prize_types'],
                'threshold_multiplier' => $normalized['threshold_multiplier'],
                'version' => ((int) $setting->version) + 1,
                'updated_by_admin_id' => $actorId,
            ]);
            $setting->save();

            $resource = $this->settingsResource($setting->refresh(), $tenantId);
            $this->audit->logAdminWrite(
                actorId: $actorId,
                scopeType: 'tenant',
                action: 'reward_risk.settings.updated',
                targetType: 'tenant_reward_risk_setting',
                targetId: (string) $setting->id,
                payload: $normalized,
                tenantId: $tenantId,
                requestId: $request->header('X-Request-Id'),
                ipAddress: $request->ip(),
                userAgent: $request->userAgent(),
            );
            $this->idempotency->storeResponse($tenantId, 'tenant_admin', $actorId, $route, $idempotencyKey, $normalized, 200, $resource, 'reward_risk.manage');

            return ['resource' => $resource];
        });

        if (($result['resource']['enabled'] ?? false) === true && ($result['replayed'] ?? false) !== true) {
            $this->dispatchLatestProvisional($tenantId);
        }

        return $result;
    }

    public function dispatchEnabledTenants(string $rewardResultId, string $phase, string $sourceHash): void
    {
        TenantRewardRiskSetting::query()
            ->where('enabled', true)
            ->select(['id', 'tenant_id'])
            ->chunkById(100, function ($settings) use ($rewardResultId, $phase, $sourceHash): void {
                foreach ($settings as $setting) {
                    EvaluateRewardRiskAssessmentJob::dispatch(
                        (string) $setting->tenant_id,
                        $rewardResultId,
                        $phase,
                        $sourceHash,
                    );
                }
            });
    }

    public function dispatchLatestProvisional(string $tenantId): void
    {
        $result = RewardResult::query()
            ->whereIn('status', ['draft', 'recorded', 'checking', 'summary_ready', 'verified'])
            ->orderByDesc('updated_at')
            ->first();

        if ($result === null) {
            return;
        }

        $summary = is_array($result->summary_json) ? $result->summary_json : [];
        $sourceHash = trim((string) ($summary['source']['payload_hash'] ?? sha1((string) $result->id.'|'.(string) $result->updated_at)));
        EvaluateRewardRiskAssessmentJob::dispatch($tenantId, (string) $result->id, 'provisional', $sourceHash);
    }

    public function supersedeRewardResult(string $rewardResultId): void
    {
        RewardRiskRun::query()
            ->where('reward_result_id', $rewardResultId)
            ->where('is_current', true)
            ->update([
                'status' => 'superseded',
                'is_current' => false,
                'superseded_at' => now(),
                'updated_at' => now(),
            ]);
    }

    public function evaluateTenant(string $tenantId, string $rewardResultId, string $phase, string $sourceHash): ?array
    {
        if (! in_array($phase, ['provisional', 'final'], true)) {
            throw new \InvalidArgumentException('Unsupported reward risk phase.');
        }

        $setting = TenantRewardRiskSetting::query()->where('tenant_id', $tenantId)->where('enabled', true)->first();
        $result = RewardResult::query()->whereKey($rewardResultId)->first();
        if ($setting === null || $result === null) {
            return null;
        }
        if ($phase === 'final' && (string) $result->status !== 'published') {
            return null;
        }
        if ($phase === 'provisional') {
            $summary = is_array($result->summary_json)
                ? $result->summary_json
                : (json_decode((string) $result->summary_json, true) ?: []);
            $currentSourceHash = trim((string) ($summary['source']['payload_hash'] ?? ''));
            if ($currentSourceHash !== '' && ! hash_equals($currentSourceHash, $sourceHash)) {
                return null;
            }
        }

        $settingsSnapshot = $this->settingsResource($setting, $tenantId);
        $effectiveHash = hash('sha256', implode('|', [$sourceHash, $phase, (string) $setting->version]));
        $run = RewardRiskRun::query()->firstOrCreate(
            [
                'tenant_id' => $tenantId,
                'reward_result_id' => $rewardResultId,
                'phase' => $phase,
                'source_hash' => $effectiveHash,
            ],
            [
                'id' => 'rru_'.Str::ulid()->toBase32(),
                'game_id' => (string) $result->game_id,
                'reward_version' => (int) $result->version,
                'settings_snapshot_json' => $settingsSnapshot,
                'status' => 'queued',
                'is_current' => true,
            ],
        );

        if ((string) $run->status === 'completed') {
            return $this->runResource($run);
        }

        $run->fill(['status' => 'processing', 'last_error' => null, 'started_at' => now()])->save();

        try {
            $assessment = $this->calculate(
                $tenantId,
                (string) $result->game_id,
                $rewardResultId,
                $phase,
                $settingsSnapshot['monitored_prize_types'],
                (string) $settingsSnapshot['threshold_multiplier'],
            );

            DB::transaction(function () use ($run, $assessment, $tenantId, $rewardResultId, $phase): void {
                RewardRiskRun::query()
                    ->where('tenant_id', $tenantId)
                    ->where('reward_result_id', $rewardResultId)
                    ->where('phase', $phase)
                    ->where('id', '!=', $run->id)
                    ->where('is_current', true)
                    ->update([
                        'status' => 'superseded',
                        'is_current' => false,
                        'superseded_at' => now(),
                        'updated_at' => now(),
                    ]);

                RewardRiskFinding::query()->where('run_id', $run->id)->delete();
                $this->insertFindings((string) $run->id, $tenantId, (string) $run->game_id, $assessment['findings']);
                RewardRiskRun::query()->whereKey($run->id)->update([
                    'status' => 'completed',
                    'is_current' => true,
                    'evaluated_group_count' => $assessment['evaluated_group_count'],
                    'finding_count' => count($assessment['findings']),
                    'total_purchase_amount' => $assessment['total_purchase_amount'],
                    'total_prize_amount' => $assessment['total_prize_amount'],
                    'currency' => 'THB',
                    'last_error' => null,
                    'completed_at' => now(),
                    'updated_at' => now(),
                ]);
            });
        } catch (\Throwable $exception) {
            RewardRiskRun::query()->whereKey($run->id)->update([
                'status' => 'failed',
                'last_error' => Str::limit($exception->getMessage(), 2000, ''),
                'updated_at' => now(),
            ]);
            throw $exception;
        }

        $fresh = RewardRiskRun::query()->whereKey($run->id)->firstOrFail();
        try {
            RewardRiskAssessmentUpdated::dispatch(
                $tenantId,
                (string) $fresh->id,
                (string) $fresh->game_id,
                $phase,
                (string) $fresh->status,
                (int) $fresh->finding_count,
            );
        } catch (\Throwable) {
            // Realtime is advisory; polling remains available when broadcasting is down.
        }

        return $this->runResource($fresh);
    }

    private function calculate(string $tenantId, string $gameId, string $rewardResultId, string $phase, array $types, string $multiplier): array
    {
        $paidTickets = Ticket::query()
            ->join('orders', function ($join): void {
                $join->on('orders.id', '=', 'tickets.order_id')->on('orders.tenant_id', '=', 'tickets.tenant_id');
            })
            ->join('order_items', function ($join): void {
                $join->on('order_items.ticket_id', '=', 'tickets.id')->on('order_items.tenant_id', '=', 'tickets.tenant_id');
            })
            ->where('tickets.tenant_id', $tenantId)
            ->where('tickets.game_id', $gameId)
            ->where('orders.payment_status', 'paid')
            ->whereNull('orders.cancelled_at')
            ->whereNull('orders.refunded_at');

        $purchaseByCustomer = [];
        $purchaseRows = (clone $paidTickets)
            ->selectRaw('tickets.customer_id, SUM(order_items.price_amount) AS purchase_amount')
            ->groupBy('tickets.customer_id')
            ->get();
        foreach ($purchaseRows as $row) {
            $purchaseByCustomer[(string) $row->customer_id] = (int) $row->purchase_amount;
        }
        $evaluatedGroupCount = DB::query()
            ->fromSub(
                (clone $paidTickets)->select(['tickets.customer_id', 'tickets.full_number'])->distinct(),
                'reward_risk_paid_groups',
            )
            ->count();

        $matches = $phase === 'final'
            ? $this->finalMatches($tenantId, $gameId, $rewardResultId, $types)
            : $this->provisionalMatches($tenantId, $rewardResultId, $types, $paidTickets);
        $groups = [];
        $totalPrizeAmount = 0;

        foreach ($matches as $match) {
            $customerId = (string) $match['customer_id'];
            $key = $customerId.'|'.(string) $match['full_number'];
            $groups[$key] ??= [
                'customer_id' => $customerId,
                'full_number' => (string) $match['full_number'],
                'prize_amount' => 0,
                'ticket_ids' => [],
                'prize_types' => [],
                'matches' => [],
            ];
            $groups[$key]['prize_amount'] += (int) $match['amount'];
            $groups[$key]['ticket_ids'][(string) $match['ticket_id']] = true;
            $groups[$key]['prize_types'][(string) $match['prize_type']] = true;
            $groups[$key]['matches'][] = $match;
            $totalPrizeAmount += (int) $match['amount'];
        }

        $multiplierHundredths = max(1, (int) round((float) $multiplier * 100));
        $findings = [];
        foreach ($groups as $group) {
            $purchaseAmount = (int) ($purchaseByCustomer[$group['customer_id']] ?? 0);
            $thresholdAmount = intdiv(($purchaseAmount * $multiplierHundredths) + 50, 100);
            if ((int) $group['prize_amount'] <= $thresholdAmount) {
                continue;
            }
            $findings[] = $group + [
                'ticket_count' => count($group['ticket_ids']),
                'purchase_amount' => $purchaseAmount,
                'threshold_multiplier' => number_format($multiplierHundredths / 100, 2, '.', ''),
                'threshold_amount' => $thresholdAmount,
                'excess_amount' => (int) $group['prize_amount'] - $thresholdAmount,
            ];
        }

        return [
            'evaluated_group_count' => $evaluatedGroupCount,
            'findings' => $findings,
            'total_purchase_amount' => array_sum($purchaseByCustomer),
            'total_prize_amount' => $totalPrizeAmount,
        ];
    }

    private function provisionalMatches(string $tenantId, string $rewardResultId, array $types, Builder $paidTickets): array
    {
        $prizes = RewardPrize::query()
            ->where('reward_result_id', $rewardResultId)
            ->whereIn('prize_type', $types)
            ->orderBy('sort_order')
            ->get()
            ->filter(fn (object $prize): bool => ! str_starts_with((string) $prize->prize_number, 'pending_'))
            ->values()
            ->all();
        $pricedPrizes = array_map(fn (object $prize): array => [
            'prize' => $prize,
            'amount' => (int) $this->rewardPrices->resolveForPrize($tenantId, (string) $prize->game_id, $prize)['effective_amount'],
        ], $prizes);
        $matches = [];

        foreach ((clone $paidTickets)
            ->select(['tickets.id', 'tickets.customer_id', 'tickets.full_number'])
            ->lazyById(500, 'tickets.id', 'id') as $ticket) {
            foreach ($pricedPrizes as $pricedPrize) {
                $prize = $pricedPrize['prize'];
                if (! $this->matcher->matches((string) $ticket->full_number, (string) $prize->prize_type, (string) $prize->prize_number)) {
                    continue;
                }
                $matches[] = [
                    'ticket_id' => (string) $ticket->id,
                    'winning_ticket_id' => null,
                    'customer_id' => (string) $ticket->customer_id,
                    'full_number' => (string) $ticket->full_number,
                    'prize_type' => (string) $prize->prize_type,
                    'prize_number' => (string) $prize->prize_number,
                    'amount' => $pricedPrize['amount'],
                    'currency' => (string) $prize->currency,
                ];
            }
        }

        return $matches;
    }

    private function finalMatches(string $tenantId, string $gameId, string $rewardResultId, array $types): array
    {
        $rows = WinningTicket::query()
            ->join('tickets', function ($join): void {
                $join->on('tickets.id', '=', 'winning_tickets.ticket_id')->on('tickets.tenant_id', '=', 'winning_tickets.tenant_id');
            })
            ->join('orders', function ($join): void {
                $join->on('orders.id', '=', 'tickets.order_id')->on('orders.tenant_id', '=', 'tickets.tenant_id');
            })
            ->where('winning_tickets.tenant_id', $tenantId)
            ->where('winning_tickets.game_id', $gameId)
            ->where('winning_tickets.reward_result_id', $rewardResultId)
            ->whereIn('winning_tickets.prize_type', $types)
            ->where('orders.payment_status', 'paid')
            ->whereNull('orders.cancelled_at')
            ->whereNull('orders.refunded_at')
            ->select([
                'winning_tickets.id', 'winning_tickets.ticket_id', 'winning_tickets.prize_type',
                'winning_tickets.prize_number', 'winning_tickets.amount', 'winning_tickets.currency',
                'tickets.customer_id', 'tickets.full_number',
            ])
            ->lazyById(500, 'winning_tickets.id', 'id');
        $matches = [];

        foreach ($rows as $row) {
            $matches[] = [
                'ticket_id' => (string) $row->ticket_id,
                'winning_ticket_id' => (string) $row->id,
                'customer_id' => (string) $row->customer_id,
                'full_number' => (string) $row->full_number,
                'prize_type' => (string) $row->prize_type,
                'prize_number' => (string) $row->prize_number,
                'amount' => (int) $row->amount,
                'currency' => (string) $row->currency,
            ];
        }

        return $matches;
    }

    private function insertFindings(string $runId, string $tenantId, string $gameId, array $findings): void
    {
        foreach ($findings as $finding) {
            $findingId = 'rrf_'.Str::ulid()->toBase32();
            RewardRiskFinding::query()->insert([
                'id' => $findingId,
                'run_id' => $runId,
                'tenant_id' => $tenantId,
                'game_id' => $gameId,
                'customer_id' => $finding['customer_id'],
                'full_number' => $finding['full_number'],
                'prize_types_json' => json_encode(array_keys($finding['prize_types']), JSON_THROW_ON_ERROR),
                'ticket_count' => $finding['ticket_count'],
                'purchase_amount' => $finding['purchase_amount'],
                'prize_amount' => $finding['prize_amount'],
                'threshold_multiplier' => $finding['threshold_multiplier'],
                'threshold_amount' => $finding['threshold_amount'],
                'excess_amount' => $finding['excess_amount'],
                'currency' => 'THB',
                'status' => 'threshold_exceeded',
                'created_at' => now(),
                'updated_at' => now(),
            ]);

            foreach ($finding['matches'] as $match) {
                RewardRiskFindingTicket::query()->insert([
                    'id' => 'rft_'.Str::ulid()->toBase32(),
                    'finding_id' => $findingId,
                    'run_id' => $runId,
                    'tenant_id' => $tenantId,
                    'ticket_id' => $match['ticket_id'],
                    'winning_ticket_id' => $match['winning_ticket_id'],
                    'prize_type' => $match['prize_type'],
                    'prize_number' => $match['prize_number'],
                    'amount' => $match['amount'],
                    'currency' => $match['currency'],
                    'created_at' => now(),
                    'updated_at' => now(),
                ]);
            }
        }
    }

    public function tenantOverview(string $tenantId, array $query = []): array
    {
        $gameId = trim((string) ($query['game_id'] ?? ''));
        $runs = RewardRiskRun::query()->where('tenant_id', $tenantId)->where('is_current', true);
        if ($gameId !== '') {
            $runs->where('game_id', $gameId);
        }
        if (($query['phase'] ?? '') !== '') {
            $runs->where('phase', (string) $query['phase']);
        }
        $latest = $runs->orderByDesc('created_at')->get()->unique('phase')->keyBy('phase');

        return [
            'settings' => $this->settings($tenantId),
            'game_id' => $gameId !== '' ? $gameId : ($latest->first()?->game_id),
            'provisional' => isset($latest['provisional']) ? $this->runResource($latest['provisional']) : null,
            'final' => isset($latest['final']) ? $this->runResource($latest['final']) : null,
        ];
    }

    public function centralOverview(array $query = []): array
    {
        $tenantId = trim((string) ($query['tenant_id'] ?? ''));
        $gameId = trim((string) ($query['game_id'] ?? ''));
        $runs = RewardRiskRun::query()->where('is_current', true)->where('status', 'completed');
        if ($tenantId !== '') {
            $runs->where('tenant_id', $tenantId);
        }
        if ($gameId !== '') {
            $runs->where('game_id', $gameId);
        }
        if (($query['phase'] ?? '') !== '') {
            $runs->where('phase', (string) $query['phase']);
        }

        $enabledTenants = TenantRewardRiskSetting::query()->where('enabled', true);
        if ($tenantId !== '') {
            $enabledTenants->where('tenant_id', $tenantId);
        }

        return [
            'enabled_tenant_count' => $enabledTenants->count(),
            'run_count' => (clone $runs)->count(),
            'finding_count' => (clone $runs)->sum('finding_count'),
            'total_prize_amount' => (int) (clone $runs)->sum('total_prize_amount'),
            'total_purchase_amount' => (int) (clone $runs)->sum('total_purchase_amount'),
            'currency' => 'THB',
        ];
    }

    public function listRuns(?string $tenantId, array $query = []): array
    {
        $builder = RewardRiskRun::query()
            ->leftJoin('partner_tenants', 'partner_tenants.id', '=', 'reward_risk_runs.tenant_id')
            ->leftJoin('partners', 'partners.id', '=', 'partner_tenants.partner_id')
            ->leftJoin('games', 'games.id', '=', 'reward_risk_runs.game_id')
            ->select('reward_risk_runs.*', 'partner_tenants.name as tenant_name', 'partners.name as partner_name', 'games.name as game_name', 'games.draw_at');
        $this->applyListFilters($builder, $tenantId, $query, 'reward_risk_runs');
        $limit = min(100, max(1, (int) ($query['limit'] ?? 30)));
        $rows = $builder->orderByDesc('reward_risk_runs.id')->limit($limit + 1)->get()->all();
        $hasMore = count($rows) > $limit;
        $rows = array_slice($rows, 0, $limit);

        return [
            'data' => array_map(fn (object $run): array => $this->runResource($run), $rows),
            'meta' => ['next_cursor' => $hasMore ? (string) end($rows)->id : null, 'has_more' => $hasMore],
        ];
    }

    public function listFindings(?string $tenantId, array $query = [], bool $masked = false): array
    {
        $builder = RewardRiskFinding::query()
            ->join('reward_risk_runs', 'reward_risk_runs.id', '=', 'reward_risk_findings.run_id')
            ->leftJoin('customers', 'customers.id', '=', 'reward_risk_findings.customer_id')
            ->leftJoin('partner_tenants', 'partner_tenants.id', '=', 'reward_risk_findings.tenant_id')
            ->leftJoin('partners', 'partners.id', '=', 'partner_tenants.partner_id')
            ->leftJoin('games', 'games.id', '=', 'reward_risk_findings.game_id')
            ->select([
                'reward_risk_findings.*', 'reward_risk_runs.phase', 'reward_risk_runs.reward_version',
                'reward_risk_runs.is_current', 'customers.customer_no', 'customers.name as customer_name',
                'customers.phone as customer_phone', 'partner_tenants.name as tenant_name',
                'partners.name as partner_name', 'games.name as game_name', 'games.draw_at',
            ]);
        $this->applyListFilters($builder, $tenantId, $query, 'reward_risk_findings');
        if (($query['prize_type'] ?? '') !== '') {
            $builder->whereJsonContains('reward_risk_findings.prize_types_json', (string) $query['prize_type']);
        }
        $limit = min(100, max(1, (int) ($query['limit'] ?? 30)));
        $rows = $builder->orderByDesc('reward_risk_findings.id')->limit($limit + 1)->get()->all();
        $hasMore = count($rows) > $limit;
        $rows = array_slice($rows, 0, $limit);

        return [
            'data' => array_map(fn (object $finding): array => $this->findingResource($finding, $masked), $rows),
            'meta' => ['next_cursor' => $hasMore ? (string) end($rows)->id : null, 'has_more' => $hasMore],
        ];
    }

    public function finding(string $findingId, ?string $tenantId, bool $masked = false): ?array
    {
        $builder = RewardRiskFinding::query()
            ->join('reward_risk_runs', 'reward_risk_runs.id', '=', 'reward_risk_findings.run_id')
            ->leftJoin('customers', 'customers.id', '=', 'reward_risk_findings.customer_id')
            ->leftJoin('partner_tenants', 'partner_tenants.id', '=', 'reward_risk_findings.tenant_id')
            ->leftJoin('partners', 'partners.id', '=', 'partner_tenants.partner_id')
            ->select('reward_risk_findings.*', 'reward_risk_runs.phase', 'reward_risk_runs.reward_version', 'customers.customer_no', 'customers.name as customer_name', 'customers.phone as customer_phone', 'partner_tenants.name as tenant_name', 'partners.name as partner_name')
            ->where('reward_risk_findings.id', $findingId);
        if ($tenantId !== null) {
            $builder->where('reward_risk_findings.tenant_id', $tenantId);
        }
        $finding = $builder->first();
        if ($finding === null) {
            return null;
        }

        $tickets = RewardRiskFindingTicket::query()->where('finding_id', $findingId)->orderBy('id')->get()->map(fn (object $row): array => [
            'id' => (string) $row->id,
            'ticket_id' => (string) ($row->ticket_id ?? ''),
            'winning_ticket_id' => (string) ($row->winning_ticket_id ?? ''),
            'prize_type' => (string) $row->prize_type,
            'prize_number' => (string) $row->prize_number,
            'amount' => (int) $row->amount,
            'currency' => (string) $row->currency,
        ])->all();

        return $this->findingResource($finding, $masked) + ['tickets' => $tickets];
    }

    private function applyListFilters($builder, ?string $tenantId, array $query, string $table): void
    {
        if ($tenantId !== null) {
            $builder->where($table.'.tenant_id', $tenantId);
        } elseif (($query['tenant_id'] ?? '') !== '') {
            $builder->where($table.'.tenant_id', (string) $query['tenant_id']);
        }
        foreach (['game_id', 'status'] as $field) {
            if (($query[$field] ?? '') !== '') {
                $builder->where($table.'.'.$field, (string) $query[$field]);
            }
        }
        if (($query['phase'] ?? '') !== '') {
            $builder->where('reward_risk_runs.phase', (string) $query['phase']);
        }
        if (($query['cursor'] ?? '') !== '') {
            $builder->where($table.'.id', '<', (string) $query['cursor']);
        }
    }

    private function settingsResource(?object $setting, string $tenantId): array
    {
        return [
            'tenant_id' => $tenantId,
            'enabled' => (bool) ($setting?->enabled ?? false),
            'monitored_prize_types' => array_values(is_array($setting?->monitored_prize_types_json) ? $setting->monitored_prize_types_json : []),
            'threshold_multiplier' => number_format((float) ($setting?->threshold_multiplier ?? 1), 2, '.', ''),
            'version' => (int) ($setting?->version ?? 0),
            'updated_at' => $setting?->updated_at,
        ];
    }

    private function runResource(object $run): array
    {
        return [
            'id' => (string) $run->id,
            'tenant_id' => (string) $run->tenant_id,
            'tenant_name' => $run->tenant_name ?? null,
            'partner_name' => $run->partner_name ?? null,
            'game_id' => (string) $run->game_id,
            'game_name' => $run->game_name ?? null,
            'draw_at' => $run->draw_at ?? null,
            'reward_result_id' => (string) ($run->reward_result_id ?? ''),
            'phase' => (string) $run->phase,
            'reward_version' => (int) $run->reward_version,
            'status' => (string) $run->status,
            'is_current' => (bool) $run->is_current,
            'evaluated_group_count' => (int) $run->evaluated_group_count,
            'finding_count' => (int) $run->finding_count,
            'total_purchase_amount' => (int) $run->total_purchase_amount,
            'total_prize_amount' => (int) $run->total_prize_amount,
            'currency' => (string) $run->currency,
            'settings_snapshot' => is_array($run->settings_snapshot_json) ? $run->settings_snapshot_json : json_decode((string) $run->settings_snapshot_json, true),
            'last_error' => $run->last_error,
            'started_at' => $run->started_at,
            'completed_at' => $run->completed_at,
            'superseded_at' => $run->superseded_at,
            'created_at' => $run->created_at,
        ];
    }

    private function findingResource(object $finding, bool $masked): array
    {
        $customerNo = (string) ($finding->customer_no ?? '');
        $phone = (string) ($finding->customer_phone ?? '');

        return [
            'id' => (string) $finding->id,
            'run_id' => (string) $finding->run_id,
            'tenant_id' => (string) $finding->tenant_id,
            'tenant_name' => $finding->tenant_name ?? null,
            'partner_name' => $finding->partner_name ?? null,
            'game_id' => (string) $finding->game_id,
            'game_name' => $finding->game_name ?? null,
            'draw_at' => $finding->draw_at ?? null,
            'phase' => (string) ($finding->phase ?? ''),
            'reward_version' => (int) ($finding->reward_version ?? 1),
            'customer' => [
                'id' => $masked ? null : (string) ($finding->customer_id ?? ''),
                'customer_no' => $masked ? $this->maskValue($customerNo, 3, 2) : $customerNo,
                'name' => $masked ? null : ($finding->customer_name ?? null),
                'phone' => $masked ? $this->maskValue($phone, 3, 2) : $phone,
            ],
            'full_number' => (string) $finding->full_number,
            'prize_types' => is_array($finding->prize_types_json) ? $finding->prize_types_json : (json_decode((string) $finding->prize_types_json, true) ?: []),
            'ticket_count' => (int) $finding->ticket_count,
            'purchase_amount' => (int) $finding->purchase_amount,
            'prize_amount' => (int) $finding->prize_amount,
            'threshold_multiplier' => number_format((float) $finding->threshold_multiplier, 2, '.', ''),
            'threshold_amount' => (int) $finding->threshold_amount,
            'excess_amount' => (int) $finding->excess_amount,
            'currency' => (string) $finding->currency,
            'status' => (string) $finding->status,
            'created_at' => $finding->created_at,
        ];
    }

    private function maskValue(string $value, int $prefix, int $suffix): string
    {
        if ($value === '') {
            return '';
        }
        if (strlen($value) <= $prefix + $suffix) {
            return str_repeat('*', strlen($value));
        }

        return substr($value, 0, $prefix).str_repeat('*', max(3, strlen($value) - $prefix - $suffix)).substr($value, -$suffix);
    }
}
