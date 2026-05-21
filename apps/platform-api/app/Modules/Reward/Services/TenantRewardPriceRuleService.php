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
     * @return array{amount: int, currency: string}
     */
    private function money(int $amount, string $currency = 'THB'): array
    {
        return ['amount' => $amount, 'currency' => $currency];
    }
}
