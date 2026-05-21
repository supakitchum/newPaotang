<?php

namespace App\Modules\Reward\Services;

use App\Models\RewardPrize;
use App\Models\RewardResult;
use App\Models\TenantPriceRule;

class TenantRewardPriceRuleService
{
    public const BASE_SOURCE_CENTRAL_REWARD = 'central_reward';
    public const RULE_TYPE_AMOUNT_DELTA = 'reward_adjustment_amount';
    public const RULE_TYPE_PERCENT_DELTA = 'reward_adjustment_percent';

    public function settingRowId(string $gameId, string $prizeType): string
    {
        return 'game:'.$gameId.':prize:'.$prizeType;
    }

    /**
     * @return array{game_id: string, prize_type: string}|null
     */
    public function settingIdentityFromId(string $rowId): ?array
    {
        if (! str_starts_with($rowId, 'game:') || ! str_contains($rowId, ':prize:')) {
            return null;
        }

        [$gameId, $prizeType] = explode(':prize:', substr($rowId, 5), 2);
        $gameId = trim($gameId);
        $prizeType = trim($prizeType);

        return $gameId === '' || $prizeType === '' ? null : [
            'game_id' => $gameId,
            'prize_type' => $prizeType,
        ];
    }

    /**
     * @return array<int, array<string, mixed>>
     */
    public function settingRows(string $tenantId, string $gameId): array
    {
        $baseRows = $this->basePrizeRows($gameId);
        $rows = [];

        foreach ($baseRows as $baseRow) {
            $rows[] = $this->settingRowFromBase($tenantId, $baseRow);
        }

        return $rows;
    }

    /**
     * @return array<string, mixed>|null
     */
    public function settingRow(string $tenantId, string $rowId): ?array
    {
        $identity = $this->settingIdentityFromId($rowId);

        if ($identity === null) {
            $rule = TenantPriceRule::query()->forTenant($tenantId)->where('id', $rowId)->first();
            $identity = $rule === null ? null : $this->identityFromRule($rule);
        }

        if ($identity === null) {
            return null;
        }

        $baseRow = $this->basePrizeRows((string) $identity['game_id'])[(string) $identity['prize_type']] ?? null;

        return $baseRow === null ? null : $this->settingRowFromBase($tenantId, $baseRow);
    }

    /**
     * @param array<string, mixed> $payload
     * @return array{resource?: array<string, mixed>, error?: string, errors?: array<string, array<int, string>>}
     */
    public function savePayoutSetting(string $tenantId, string $rowId, array $payload): array
    {
        $identity = $this->settingIdentityFromId($rowId) ?? [
            'game_id' => trim((string) ($payload['game_id'] ?? '')),
            'prize_type' => trim((string) ($payload['prize_type'] ?? '')),
        ];
        $gameId = trim((string) ($identity['game_id'] ?? ''));
        $prizeType = trim((string) ($identity['prize_type'] ?? ''));
        $baseRow = $gameId === '' || $prizeType === '' ? null : ($this->basePrizeRows($gameId)[$prizeType] ?? null);

        if ($baseRow === null) {
            return ['error' => 'not_found'];
        }

        $partnerPayoutAmount = $this->moneyInputAmount($payload['partner_payout_amount'] ?? $payload['payout_amount'] ?? $payload['price_amount'] ?? null);

        if ($partnerPayoutAmount === null) {
            return ['error' => 'validation_failed', 'errors' => [
                'partner_payout_amount' => ['The partner_payout_amount field is required.'],
            ]];
        }

        if ($partnerPayoutAmount < 0) {
            return ['error' => 'validation_failed', 'errors' => [
                'partner_payout_amount' => ['The partner_payout_amount field must be at least zero.'],
            ]];
        }

        $baseAmount = (int) $baseRow['central_reward_amount']['amount'];
        $adjustmentAmount = $partnerPayoutAmount - $baseAmount;
        $rule = $this->existingSettingRule($tenantId, $gameId, $prizeType);
        $ruleId = $rule?->id ?? $this->deterministicRuleId($tenantId, $gameId, $prizeType);
        $now = now();

        TenantPriceRule::query()->updateOrInsert(
            ['id' => $ruleId],
            [
                'tenant_id' => $tenantId,
                'game_id' => $gameId,
                'code' => $this->settingCode($gameId, $prizeType),
                'name' => $this->prizeTypeLabel($prizeType).' payout',
                'rule_type' => self::RULE_TYPE_AMOUNT_DELTA,
                'base_source' => self::BASE_SOURCE_CENTRAL_REWARD,
                'price_amount' => abs($adjustmentAmount),
                'adjustment_amount' => $adjustmentAmount,
                'adjustment_bps' => null,
                'currency' => (string) $baseRow['central_reward_amount']['currency'],
                'status' => 'active',
                'conditions_json' => json_encode(['prize_type' => $prizeType], JSON_THROW_ON_ERROR),
                'created_at' => $rule?->created_at ?? $now,
                'updated_at' => $now,
            ],
        );

        return ['resource' => $this->settingRow($tenantId, $this->settingRowId($gameId, $prizeType)) ?? []];
    }

    /**
     * @return array<string, mixed>
     */
    public function resolveForPrize(string $tenantId, string $gameId, object $prize): array
    {
        $baseAmount = (int) $prize->amount;
        $currency = (string) ($prize->currency ?? 'THB');
        $rule = $this->matchingRules($tenantId, $gameId, $prize)[0] ?? null;
        $adjustmentAmount = $rule === null ? 0 : $this->adjustmentForRule($rule, $baseAmount);
        $effectiveAmount = max(0, $baseAmount + $adjustmentAmount);

        return [
            'base_source' => self::BASE_SOURCE_CENTRAL_REWARD,
            'base_amount' => $baseAmount,
            'adjustment_amount' => $adjustmentAmount,
            'effective_amount' => $effectiveAmount,
            'currency' => $currency,
            'tenant_price_rule_id' => $rule?->id,
            'price_rule_snapshot' => $rule === null ? null : $this->ruleSnapshot($rule),
        ];
    }

    /**
     * @return array{summary: array<string, mixed>, prizes: array<int, array<string, mixed>>}
     */
    public function previewRule(TenantPriceRule $rule): array
    {
        $prizes = [];
        $gameId = $rule->game_id === null ? null : (string) $rule->game_id;

        if ($gameId !== null && $gameId !== '') {
            $prizes = RewardPrize::query()
                ->where('game_id', $gameId)
                ->orderBy('sort_order')
                ->get()
                ->filter(fn (object $prize): bool => $this->ruleMatchesPrize($rule, $prize))
                ->map(function (object $prize) use ($rule): array {
                    $baseAmount = (int) $prize->amount;
                    $adjustmentAmount = $this->adjustmentForRule($rule, $baseAmount);
                    $effectiveAmount = max(0, $baseAmount + $adjustmentAmount);
                    $currency = (string) ($prize->currency ?? $rule->currency ?? 'THB');

                    return [
                        'reward_result_id' => (string) $prize->reward_result_id,
                        'reward_prize_id' => (string) $prize->id,
                        'game_id' => (string) $prize->game_id,
                        'prize_type' => (string) $prize->prize_type,
                        'prize_number' => (string) $prize->prize_number,
                        'base_amount' => $this->money($baseAmount, $currency),
                        'adjustment_amount' => $this->money($adjustmentAmount, $currency),
                        'effective_amount' => $this->money($effectiveAmount, $currency),
                    ];
                })
                ->values()
                ->all();
        }

        $currency = (string) ($rule->currency ?? 'THB');
        $baseTotal = array_sum(array_map(fn (array $row): int => (int) ($row['base_amount']['amount'] ?? 0), $prizes));
        $adjustmentTotal = array_sum(array_map(fn (array $row): int => (int) ($row['adjustment_amount']['amount'] ?? 0), $prizes));
        $effectiveTotal = array_sum(array_map(fn (array $row): int => (int) ($row['effective_amount']['amount'] ?? 0), $prizes));

        return [
            'summary' => [
                'base_source' => self::BASE_SOURCE_CENTRAL_REWARD,
                'reward_result_id' => $gameId === null ? null : RewardResult::query()->where('game_id', $gameId)->value('id'),
                'matched_prize_count' => count($prizes),
                'base_total' => $this->money($baseTotal, $currency),
                'adjustment_total' => $this->money($adjustmentTotal, $currency),
                'effective_total' => $this->money($effectiveTotal, $currency),
            ],
            'prizes' => $prizes,
        ];
    }

    /**
     * @param array<string, mixed> $payload
     * @return array<string, array<int, string>>
     */
    public function validateRulePayload(array $payload): array
    {
        $errors = [];
        $baseSource = (string) ($payload['base_source'] ?? self::BASE_SOURCE_CENTRAL_REWARD);
        $gameId = trim((string) ($payload['game_id'] ?? ''));

        if ($baseSource !== self::BASE_SOURCE_CENTRAL_REWARD) {
            $errors['base_source'][] = 'The base_source field must be central_reward.';
        }

        if (($payload['rule_type'] ?? self::RULE_TYPE_AMOUNT_DELTA) === self::RULE_TYPE_PERCENT_DELTA && ! array_key_exists('adjustment_bps', $payload)) {
            $errors['adjustment_bps'][] = 'The adjustment_bps field is required for percent reward adjustments.';
        }

        if ($gameId === '') {
            return $errors;
        }

        $rule = new TenantPriceRule($payload);
        $rule->id = $payload['id'] ?? 'preview';
        $rule->conditions_json = $payload['conditions_json'] ?? [];
        $rule->currency = $payload['currency'] ?? 'THB';
        $rule->game_id = $gameId;

        $prizes = RewardPrize::query()->where('game_id', $gameId)->orderBy('sort_order')->get()->all();

        foreach ($prizes as $prize) {
            if (! $this->ruleMatchesPrize($rule, $prize)) {
                continue;
            }

            $baseAmount = (int) $prize->amount;
            $effectiveAmount = $baseAmount + $this->adjustmentForRule($rule, $baseAmount);

            if ($effectiveAmount < 0) {
                $errors['adjustment_amount'][] = 'The adjustment makes at least one central reward amount negative.';
                break;
            }
        }

        return $errors;
    }

    /**
     * @return array<int, TenantPriceRule>
     */
    private function matchingRules(string $tenantId, string $gameId, object $prize): array
    {
        return TenantPriceRule::query()
            ->forTenant($tenantId)
            ->where('status', 'active')
            ->where('base_source', self::BASE_SOURCE_CENTRAL_REWARD)
            ->where(function ($query) use ($gameId): void {
                $query->where('game_id', $gameId)->orWhereNull('game_id');
            })
            ->get()
            ->filter(fn (TenantPriceRule $rule): bool => $this->ruleMatchesPrize($rule, $prize))
            ->sortByDesc(fn (TenantPriceRule $rule): int => $this->rulePriority($rule, $gameId, $prize))
            ->values()
            ->all();
    }

    private function ruleMatchesPrize(TenantPriceRule $rule, object $prize): bool
    {
        $conditions = is_array($rule->conditions_json) ? $rule->conditions_json : [];
        $prizeType = (string) $prize->prize_type;
        $prizeNumber = (string) $prize->prize_number;
        $hasPrizeCondition = isset($conditions['prize_type'])
            || isset($conditions['prize_types'])
            || isset($conditions['prize_number'])
            || isset($conditions['prize_numbers']);

        if (! $hasPrizeCondition) {
            return false;
        }

        if (isset($conditions['prize_type']) && ! $this->matchesOneOrAny((string) $conditions['prize_type'], $prizeType)) {
            return false;
        }

        if (isset($conditions['prize_types']) && is_array($conditions['prize_types']) && ! in_array($prizeType, array_map('strval', $conditions['prize_types']), true)) {
            return false;
        }

        if (isset($conditions['prize_number']) && ! $this->matchesOneOrAny((string) $conditions['prize_number'], $prizeNumber)) {
            return false;
        }

        if (isset($conditions['prize_numbers']) && is_array($conditions['prize_numbers']) && ! in_array($prizeNumber, array_map('strval', $conditions['prize_numbers']), true)) {
            return false;
        }

        return true;
    }

    private function rulePriority(TenantPriceRule $rule, string $gameId, object $prize): int
    {
        $conditions = is_array($rule->conditions_json) ? $rule->conditions_json : [];
        $priority = (string) $rule->game_id === $gameId ? 100 : 0;

        if (($conditions['prize_type'] ?? null) === (string) $prize->prize_type) {
            $priority += 20;
        } elseif (isset($conditions['prize_types']) && is_array($conditions['prize_types']) && in_array((string) $prize->prize_type, array_map('strval', $conditions['prize_types']), true)) {
            $priority += 10;
        }

        if (($conditions['prize_number'] ?? null) === (string) $prize->prize_number) {
            $priority += 5;
        }

        return $priority;
    }

    private function adjustmentForRule(TenantPriceRule $rule, int $baseAmount): int
    {
        if ((string) $rule->rule_type === self::RULE_TYPE_PERCENT_DELTA) {
            return (int) round($baseAmount * (int) ($rule->adjustment_bps ?? 0) / 10000);
        }

        return (int) ($rule->adjustment_amount ?? 0);
    }

    /**
     * @return array<string, mixed>
     */
    private function ruleSnapshot(TenantPriceRule $rule): array
    {
        return [
            'id' => (string) $rule->id,
            'code' => (string) $rule->code,
            'name' => (string) $rule->name,
            'game_id' => $rule->game_id,
            'base_source' => (string) $rule->base_source,
            'rule_type' => (string) $rule->rule_type,
            'adjustment_amount' => (int) ($rule->adjustment_amount ?? 0),
            'adjustment_bps' => $rule->adjustment_bps === null ? null : (int) $rule->adjustment_bps,
            'currency' => (string) $rule->currency,
            'conditions' => is_array($rule->conditions_json) ? $rule->conditions_json : [],
        ];
    }

    private function matchesOneOrAny(string $condition, string $actual): bool
    {
        return $condition === '*' || $condition === $actual;
    }

    /**
     * @return array<string, array<string, mixed>>
     */
    private function basePrizeRows(string $gameId): array
    {
        $rows = [];

        foreach (ThaiGovernmentLotteryRewardTemplate::rules() as $type => $rule) {
            $rows[$type] = [
                'id' => $this->settingRowId($gameId, $type),
                'game_id' => $gameId,
                'prize_type' => $type,
                'prize_label' => $this->prizeTypeLabel($type),
                'prize_count' => (int) $rule['count'],
                'digits' => (int) $rule['digits'],
                'central_reward_amount' => $this->money((int) $rule['amount'], ThaiGovernmentLotteryRewardTemplate::CURRENCY),
                'reward_result_id' => null,
                'source' => 'central_reward_template',
                'updated_at' => null,
            ];
        }

        $rewardPrizes = RewardPrize::query()
            ->where('game_id', $gameId)
            ->orderBy('sort_order')
            ->get()
            ->groupBy(fn (object $prize): string => (string) $prize->prize_type);

        foreach ($rewardPrizes as $type => $prizes) {
            $first = $prizes->first();
            if ($first === null) {
                continue;
            }

            $rows[(string) $type] = array_merge($rows[(string) $type] ?? [
                'id' => $this->settingRowId($gameId, (string) $type),
                'game_id' => $gameId,
                'prize_type' => (string) $type,
                'prize_label' => $this->prizeTypeLabel((string) $type),
                'digits' => strlen((string) $first->prize_number),
            ], [
                'prize_count' => $prizes->count(),
                'central_reward_amount' => $this->money((int) $first->amount, (string) $first->currency),
                'reward_result_id' => (string) $first->reward_result_id,
                'source' => 'reward_result',
                'updated_at' => $first->updated_at,
            ]);
        }

        return $rows;
    }

    /**
     * @param array<string, mixed> $baseRow
     * @return array<string, mixed>
     */
    private function settingRowFromBase(string $tenantId, array $baseRow): array
    {
        $gameId = (string) $baseRow['game_id'];
        $prizeType = (string) $baseRow['prize_type'];
        $currency = (string) ($baseRow['central_reward_amount']['currency'] ?? ThaiGovernmentLotteryRewardTemplate::CURRENCY);
        $baseAmount = (int) ($baseRow['central_reward_amount']['amount'] ?? 0);
        $rule = $this->existingSettingRule($tenantId, $gameId, $prizeType);
        $adjustmentAmount = $rule === null ? 0 : $this->adjustmentForRule($rule, $baseAmount);
        $partnerPayoutAmount = max(0, $baseAmount + $adjustmentAmount);

        return [
            'id' => $this->settingRowId($gameId, $prizeType),
            'tenant_id' => $tenantId,
            'game_id' => $gameId,
            'prize_type' => $prizeType,
            'prize_label' => (string) $baseRow['prize_label'],
            'prize_count' => (int) $baseRow['prize_count'],
            'digits' => (int) $baseRow['digits'],
            'base_source' => self::BASE_SOURCE_CENTRAL_REWARD,
            'central_reward_amount' => $this->money($baseAmount, $currency),
            'partner_payout_amount' => $this->money($partnerPayoutAmount, $currency),
            'adjustment_amount' => $this->money($adjustmentAmount, $currency),
            'tenant_price_rule_id' => $rule?->id,
            'price_rule_snapshot' => $rule === null ? null : $this->ruleSnapshot($rule),
            'reward_result_id' => $baseRow['reward_result_id'] ?? null,
            'source' => $baseRow['source'] ?? 'central_reward_template',
            'status' => 'active',
            'updated_at' => $rule?->updated_at ?? ($baseRow['updated_at'] ?? null),
        ];
    }

    private function existingSettingRule(string $tenantId, string $gameId, string $prizeType): ?TenantPriceRule
    {
        return TenantPriceRule::query()
            ->forTenant($tenantId)
            ->where('game_id', $gameId)
            ->where('base_source', self::BASE_SOURCE_CENTRAL_REWARD)
            ->where('status', 'active')
            ->orderByDesc('updated_at')
            ->get()
            ->first(function (TenantPriceRule $rule) use ($prizeType): bool {
                $identity = $this->identityFromRule($rule);

                return ($identity['prize_type'] ?? null) === $prizeType;
            });
    }

    /**
     * @return array{game_id: string, prize_type: string}|null
     */
    private function identityFromRule(TenantPriceRule $rule): ?array
    {
        $conditions = is_array($rule->conditions_json) ? $rule->conditions_json : [];
        $prizeType = is_string($conditions['prize_type'] ?? null) ? trim((string) $conditions['prize_type']) : '';

        if ($prizeType === '' || $prizeType === '*') {
            return null;
        }

        $gameId = trim((string) $rule->game_id);

        return $gameId === '' ? null : [
            'game_id' => $gameId,
            'prize_type' => $prizeType,
        ];
    }

    private function deterministicRuleId(string $tenantId, string $gameId, string $prizeType): string
    {
        return 'prr_'.substr(sha1($tenantId.':'.$gameId.':'.$prizeType), 0, 20);
    }

    private function settingCode(string $gameId, string $prizeType): string
    {
        $safeGame = preg_replace('/[^a-z0-9]+/i', '_', strtolower($gameId)) ?: 'game';

        return 'reward_'.$safeGame.'_'.$prizeType;
    }

    private function prizeTypeLabel(string $type): string
    {
        return ucwords(str_replace('_', ' ', $type));
    }

    private function moneyInputAmount(mixed $value): ?int
    {
        if (is_array($value)) {
            $value = $value['amount'] ?? null;
        }

        if ($value === null || $value === '') {
            return null;
        }

        return filter_var($value, FILTER_VALIDATE_INT) === false ? null : (int) $value;
    }

    /**
     * @return array{amount: int, currency: string}
     */
    private function money(int $amount, string $currency = 'THB'): array
    {
        return ['amount' => $amount, 'currency' => $currency];
    }
}
