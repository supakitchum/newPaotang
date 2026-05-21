<?php

namespace App\Modules\Pricing\Services;

use App\Models\Game;
use App\Models\GameSalePriceRule;
use App\Models\PartnerTenant;
use App\Models\TenantSalePriceOverride;
use Illuminate\Support\Str;

class LotterySalePriceService
{
    private const DEFAULT_UNIT_AMOUNT = 8000;
    private const DEFAULT_CURRENCY = 'THB';

    /**
     * @return array<string, mixed>
     */
    public function effectivePrice(string $tenantId, string $gameId, int $setSize = 1): array
    {
        $setSize = max(1, min(99, $setSize));
        $central = $this->centralEffectivePrice($gameId, $setSize);
        $override = TenantSalePriceOverride::query()
            ->where('tenant_id', $tenantId)
            ->where('game_id', $gameId)
            ->where('set_size', $setSize)
            ->where('status', 'active')
            ->first();

        if ($override !== null && (int) $override->price_amount >= (int) $central['amount']) {
            return [
                'amount' => (int) $override->price_amount,
                'currency' => (string) $override->currency,
                'set_size' => $setSize,
                'source' => 'tenant_override',
                'central_amount' => (int) $central['amount'],
                'central_rule_id' => $central['rule_id'],
                'tenant_override_id' => (string) $override->id,
                'fallback' => (bool) $central['fallback'],
            ];
        }

        return [
            'amount' => (int) $central['amount'],
            'currency' => (string) $central['currency'],
            'set_size' => $setSize,
            'source' => 'central',
            'central_amount' => (int) $central['amount'],
            'central_rule_id' => $central['rule_id'],
            'tenant_override_id' => null,
            'fallback' => (bool) $central['fallback'],
        ];
    }

    /**
     * @param array<int, object> $stockRows
     * @return array{items: array<string, array<string, mixed>>, total_amount: int, currency: string}
     */
    public function allocatePricesForStockRows(string $tenantId, array $stockRows): array
    {
        $groups = [];

        foreach ($stockRows as $stock) {
            $key = (string) $stock->game_id.':'.(string) $stock->full_number;
            $groups[$key][] = $stock;
        }

        $items = [];
        $total = 0;
        $currency = self::DEFAULT_CURRENCY;

        foreach ($groups as $groupRows) {
            $setSize = count($groupRows);
            $price = $this->effectivePrice($tenantId, (string) $groupRows[0]->game_id, $setSize);
            $amount = (int) $price['amount'];
            $currency = (string) $price['currency'];
            $base = intdiv($amount, max(1, $setSize));
            $remainder = $amount - ($base * $setSize);

            foreach (array_values($groupRows) as $index => $stock) {
                $itemAmount = $base + ($index < $remainder ? 1 : 0);
                $total += $itemAmount;
                $items[(string) $stock->id] = [
                    'amount' => $itemAmount,
                    'currency' => $currency,
                    'summary' => $this->summary($price),
                    'snapshot' => $this->snapshot($price, (string) $stock->game_id, (string) $stock->full_number),
                ];
            }
        }

        return [
            'items' => $items,
            'total_amount' => $total,
            'currency' => $currency,
        ];
    }

    /**
     * @param array<string, mixed> $queryParams
     * @return array{data: array<int, array<string, mixed>>, meta: array<string, mixed>}
     */
    public function listCentralRules(array $queryParams): array
    {
        $gameId = $this->queryGameId($queryParams) ?? $this->latestOpenGameId();
        $status = trim((string) ($queryParams['status'] ?? ''));
        $query = GameSalePriceRule::query()
            ->when($gameId !== null, fn ($builder) => $builder->where('game_id', $gameId))
            ->when($status !== '', fn ($builder) => $builder->where('status', $status))
            ->orderBy('game_id')
            ->orderBy('set_size')
            ->orderBy('id');

        return $this->paginateQuery($query, $queryParams, fn (object $row): array => $this->centralRuleResource($row), [
            'default_game_id' => $gameId,
        ]);
    }

    /**
     * @return array<string, mixed>|null
     */
    public function findCentralRule(string $ruleId): ?array
    {
        $rule = GameSalePriceRule::query()->where('id', $ruleId)->first();

        return $rule === null ? null : $this->centralRuleResource($rule);
    }

    /**
     * @param array<string, mixed> $payload
     * @return array{resource?: array<string, mixed>, errors?: array<string, array<int, string>>, error?: string}
     */
    public function upsertCentralRule(array $payload, ?string $ruleId = null): array
    {
        $normalized = $this->normalizeRulePayload($payload);
        $errors = $this->centralRuleErrors($normalized, $ruleId);

        if ($errors !== []) {
            return ['errors' => $errors];
        }

        $now = now();
        $rule = $ruleId === null ? null : GameSalePriceRule::query()->where('id', $ruleId)->first();

        if ($rule === null) {
            $existingId = GameSalePriceRule::query()
                ->where('game_id', $normalized['game_id'])
                ->where('set_size', $normalized['set_size'])
                ->value('id');
            $rule = $existingId === null ? null : GameSalePriceRule::query()->where('id', $existingId)->first();
        }

        $id = $rule?->id ?? 'gsp_'.Str::ulid()->toBase32();
        GameSalePriceRule::query()->updateOrInsert(
            ['id' => $id],
            [
                'game_id' => $normalized['game_id'],
                'set_size' => $normalized['set_size'],
                'price_amount' => $normalized['price_amount'],
                'currency' => $normalized['currency'],
                'status' => $normalized['status'],
                'created_at' => $rule?->created_at ?? $now,
                'updated_at' => $now,
            ],
        );

        return ['resource' => $this->findCentralRule((string) $id)];
    }

    /**
     * @param array<string, mixed> $queryParams
     * @return array{data: array<int, array<string, mixed>>, meta: array<string, mixed>}
     */
    public function listTenantRules(string $tenantId, array $queryParams): array
    {
        $gameId = $this->queryGameId($queryParams) ?? $this->latestOpenGameId();

        if ($gameId === null) {
            return ['data' => [], 'meta' => ['default_game_id' => null, 'next_cursor' => null, 'has_more' => false]];
        }

        $centralRows = GameSalePriceRule::query()
            ->where('game_id', $gameId)
            ->orderBy('set_size')
            ->get()
            ->all();
        $overrideRows = TenantSalePriceOverride::query()
            ->where('tenant_id', $tenantId)
            ->where('game_id', $gameId)
            ->get()
            ->keyBy('set_size');
        $rows = [];

        foreach ($centralRows as $central) {
            $setSize = (int) $central->set_size;
            $rows[] = $this->tenantRuleResource($tenantId, $gameId, $setSize, $central, $overrideRows->get($setSize));
        }

        foreach ($overrideRows as $setSize => $override) {
            if (! collect($centralRows)->contains(fn (object $row): bool => (int) $row->set_size === (int) $setSize)) {
                $rows[] = $this->tenantRuleResource($tenantId, $gameId, (int) $setSize, null, $override);
            }
        }

        usort($rows, fn (array $a, array $b): int => ((int) $a['set_size']) <=> ((int) $b['set_size']));

        return $this->paginateArray($rows, $queryParams, ['default_game_id' => $gameId]);
    }

    /**
     * @return array<string, mixed>|null
     */
    public function findTenantRule(string $tenantId, string $ruleId): ?array
    {
        $override = TenantSalePriceOverride::query()->where('tenant_id', $tenantId)->where('id', $ruleId)->first();

        if ($override !== null) {
            return $this->tenantRuleResource($tenantId, (string) $override->game_id, (int) $override->set_size, null, $override);
        }

        $synthetic = $this->parseSyntheticTenantRuleId($ruleId);

        if ($synthetic === null) {
            return null;
        }

        return $this->tenantRuleResource($tenantId, $synthetic['game_id'], $synthetic['set_size'], null, null);
    }

    /**
     * @param array<string, mixed> $payload
     * @return array{resource?: array<string, mixed>, errors?: array<string, array<int, string>>, error?: string}
     */
    public function upsertTenantRule(string $tenantId, array $payload, ?string $ruleId = null): array
    {
        $synthetic = $ruleId === null ? null : $this->parseSyntheticTenantRuleId($ruleId);
        $existing = $ruleId === null ? null : TenantSalePriceOverride::query()->where('tenant_id', $tenantId)->where('id', $ruleId)->first();
        $normalized = $this->normalizeRulePayload([
            ...($synthetic ?? []),
            ...($existing === null ? [] : [
                'game_id' => (string) $existing->game_id,
                'set_size' => (int) $existing->set_size,
            ]),
            ...$payload,
        ]);
        $errors = $this->tenantRuleErrors($tenantId, $normalized);

        if ($errors !== []) {
            return ['errors' => $errors];
        }

        $partnerId = PartnerTenant::query()->where('id', $tenantId)->value('partner_id');

        if ($partnerId === null) {
            return ['error' => 'not_found'];
        }

        $now = now();
        $override = $existing ?? TenantSalePriceOverride::query()
            ->where('tenant_id', $tenantId)
            ->where('game_id', $normalized['game_id'])
            ->where('set_size', $normalized['set_size'])
            ->first();
        $id = $override?->id ?? 'tsp_'.Str::ulid()->toBase32();

        TenantSalePriceOverride::query()->updateOrInsert(
            ['id' => $id],
            [
                'tenant_id' => $tenantId,
                'partner_id' => (string) $partnerId,
                'game_id' => $normalized['game_id'],
                'set_size' => $normalized['set_size'],
                'price_amount' => $normalized['price_amount'],
                'currency' => $normalized['currency'],
                'status' => $normalized['status'],
                'created_at' => $override?->created_at ?? $now,
                'updated_at' => $now,
            ],
        );

        return ['resource' => $this->findTenantRule($tenantId, (string) $id)];
    }

    /**
     * @return array{data: array<int, array<string, mixed>>, meta: array<string, mixed>}
     */
    public function gameOptions(): array
    {
        $defaultGameId = $this->latestOpenGameId();
        $rows = Game::query()
            ->orderByRaw("CASE WHEN status = 'open' THEN 0 ELSE 1 END")
            ->orderByDesc('draw_at')
            ->limit(100)
            ->get()
            ->map(fn (object $game): array => [
                'id' => (string) $game->id,
                'code' => (string) $game->code,
                'name' => (string) $game->name,
                'status' => (string) $game->status,
                'sale_start_at' => $game->sale_start_at,
                'draw_at' => $game->draw_at,
                'close_at' => $game->close_at,
                'is_default' => (string) $game->id === $defaultGameId,
            ])
            ->all();

        return ['data' => $rows, 'meta' => ['default_game_id' => $defaultGameId]];
    }

    /**
     * @return array<string, mixed>
     */
    public function summary(array $price): array
    {
        return [
            'set_size' => (int) $price['set_size'],
            'source' => (string) $price['source'],
            'central_amount' => ['amount' => (int) $price['central_amount'], 'currency' => (string) $price['currency']],
            'effective_amount' => ['amount' => (int) $price['amount'], 'currency' => (string) $price['currency']],
            'fallback' => (bool) $price['fallback'],
        ];
    }

    /**
     * @return array<string, mixed>
     */
    public function snapshot(array $price, string $gameId, string $fullNumber): array
    {
        return [
            ...$this->summary($price),
            'game_id' => $gameId,
            'full_number' => $fullNumber,
            'central_rule_id' => $price['central_rule_id'],
            'tenant_override_id' => $price['tenant_override_id'],
        ];
    }

    /**
     * @return array{amount: int, currency: string, rule_id: ?string, fallback: bool}
     */
    private function centralEffectivePrice(string $gameId, int $setSize): array
    {
        $exact = GameSalePriceRule::query()
            ->where('game_id', $gameId)
            ->where('set_size', $setSize)
            ->where('status', 'active')
            ->first();

        if ($exact !== null) {
            return [
                'amount' => (int) $exact->price_amount,
                'currency' => (string) $exact->currency,
                'rule_id' => (string) $exact->id,
                'fallback' => false,
            ];
        }

        $unit = GameSalePriceRule::query()
            ->where('game_id', $gameId)
            ->where('set_size', 1)
            ->where('status', 'active')
            ->first();
        $unitAmount = $unit === null ? self::DEFAULT_UNIT_AMOUNT : (int) $unit->price_amount;

        return [
            'amount' => $unitAmount * $setSize,
            'currency' => $unit === null ? self::DEFAULT_CURRENCY : (string) $unit->currency,
            'rule_id' => $unit === null ? null : (string) $unit->id,
            'fallback' => true,
        ];
    }

    /**
     * @return array<string, mixed>
     */
    private function centralRuleResource(object $rule): array
    {
        $game = Game::query()->where('id', $rule->game_id)->first();

        return [
            'id' => (string) $rule->id,
            'game_id' => (string) $rule->game_id,
            'game_name' => $game?->name,
            'game_code' => $game?->code,
            'set_size' => (int) $rule->set_size,
            'price' => $this->money((int) $rule->price_amount, (string) $rule->currency),
            'price_amount' => (int) $rule->price_amount,
            'currency' => (string) $rule->currency,
            'status' => (string) $rule->status,
            'source' => 'central',
            'created_at' => $rule->created_at,
            'updated_at' => $rule->updated_at,
        ];
    }

    /**
     * @return array<string, mixed>
     */
    private function tenantRuleResource(string $tenantId, string $gameId, int $setSize, ?object $central, ?object $override): array
    {
        $effective = $this->effectivePrice($tenantId, $gameId, $setSize);
        $centralPrice = $this->centralEffectivePrice($gameId, $setSize);
        $game = Game::query()->where('id', $gameId)->first();

        return [
            'id' => $override?->id ?? $this->syntheticTenantRuleId($gameId, $setSize),
            'override_id' => $override?->id,
            'game_id' => $gameId,
            'game_name' => $game?->name,
            'game_code' => $game?->code,
            'set_size' => $setSize,
            'central_price' => $this->money((int) $centralPrice['amount'], (string) $centralPrice['currency']),
            'partner_price' => $this->money((int) $effective['amount'], (string) $effective['currency']),
            'price' => $this->money((int) $effective['amount'], (string) $effective['currency']),
            'price_amount' => (int) $effective['amount'],
            'currency' => (string) $effective['currency'],
            'central_rule_id' => $central?->id ?? $centralPrice['rule_id'],
            'source' => (string) $effective['source'],
            'status' => $override?->status ?? 'central_default',
            'created_at' => $override?->created_at,
            'updated_at' => $override?->updated_at ?? $central?->updated_at,
        ];
    }

    /**
     * @param array<string, mixed> $payload
     * @return array{game_id: string, set_size: int, price_amount: int, currency: string, status: string}
     */
    private function normalizeRulePayload(array $payload): array
    {
        return [
            'game_id' => trim((string) ($payload['game_id'] ?? '')),
            'set_size' => max(0, (int) ($payload['set_size'] ?? 0)),
            'price_amount' => max(0, (int) ($payload['price_amount'] ?? data_get($payload, 'price.amount', 0))),
            'currency' => strtoupper(trim((string) ($payload['currency'] ?? data_get($payload, 'price.currency', self::DEFAULT_CURRENCY)))) ?: self::DEFAULT_CURRENCY,
            'status' => trim((string) ($payload['status'] ?? 'active')) ?: 'active',
        ];
    }

    /**
     * @param array<string, mixed> $payload
     * @return array<string, array<int, string>>
     */
    private function centralRuleErrors(array $payload, ?string $ruleId): array
    {
        $errors = $this->baseRuleErrors($payload);

        if ($errors === []) {
            $conflict = GameSalePriceRule::query()
                ->where('game_id', $payload['game_id'])
                ->where('set_size', $payload['set_size'])
                ->when($ruleId !== null, fn ($query) => $query->where('id', '<>', $ruleId))
                ->exists();

            if ($conflict) {
                $errors['set_size'][] = 'The set size already has a central sale price for this game.';
            }
        }

        return $errors;
    }

    /**
     * @param array<string, mixed> $payload
     * @return array<string, array<int, string>>
     */
    private function tenantRuleErrors(string $tenantId, array $payload): array
    {
        $errors = $this->baseRuleErrors($payload);

        if ($errors !== []) {
            return $errors;
        }

        if (PartnerTenant::query()->where('id', $tenantId)->doesntExist()) {
            $errors['tenant_id'][] = 'The tenant was not found.';
            return $errors;
        }

        $central = $this->centralEffectivePrice($payload['game_id'], $payload['set_size']);

        if ((int) $payload['price_amount'] < (int) $central['amount']) {
            $errors['price_amount'][] = 'The partner sale price must be greater than or equal to the central sale price.';
        }

        return $errors;
    }

    /**
     * @param array<string, mixed> $payload
     * @return array<string, array<int, string>>
     */
    private function baseRuleErrors(array $payload): array
    {
        $errors = [];

        if ($payload['game_id'] === '' || Game::query()->where('id', $payload['game_id'])->doesntExist()) {
            $errors['game_id'][] = 'The game_id field must reference an existing game.';
        }

        if ((int) $payload['set_size'] < 1 || (int) $payload['set_size'] > 99) {
            $errors['set_size'][] = 'The set size must be between 1 and 99.';
        }

        if ((int) $payload['price_amount'] <= 0) {
            $errors['price_amount'][] = 'The price amount must be greater than zero.';
        }

        if (! preg_match('/^[A-Z]{3}$/', (string) $payload['currency'])) {
            $errors['currency'][] = 'The currency field must be a three-letter code.';
        }

        if (! in_array((string) $payload['status'], ['active', 'inactive', 'archived'], true)) {
            $errors['status'][] = 'The status field is invalid.';
        }

        return $errors;
    }

    private function queryGameId(array $queryParams): ?string
    {
        $gameId = trim((string) ($queryParams['game_id'] ?? ''));

        return $gameId === '' ? null : $gameId;
    }

    private function latestOpenGameId(): ?string
    {
        $gameId = Game::query()
            ->where('status', 'open')
            ->orderByDesc('draw_at')
            ->value('id');

        return $gameId === null ? null : (string) $gameId;
    }

    private function syntheticTenantRuleId(string $gameId, int $setSize): string
    {
        return 'eff:'.$gameId.':'.$setSize;
    }

    /**
     * @return array{game_id: string, set_size: int}|null
     */
    private function parseSyntheticTenantRuleId(string $id): ?array
    {
        $parts = explode(':', $id);

        if (count($parts) !== 3 || $parts[0] !== 'eff') {
            return null;
        }

        return [
            'game_id' => $parts[1],
            'set_size' => max(1, (int) $parts[2]),
        ];
    }

    private function money(int $amount, string $currency = self::DEFAULT_CURRENCY): array
    {
        return ['amount' => $amount, 'currency' => $currency];
    }

    /**
     * @param \Illuminate\Database\Eloquent\Builder $query
     * @param array<string, mixed> $queryParams
     * @param array<string, mixed> $meta
     * @return array{data: array<int, array<string, mixed>>, meta: array<string, mixed>}
     */
    private function paginateQuery($query, array $queryParams, callable $resource, array $meta = []): array
    {
        $limit = $this->limit($queryParams['limit'] ?? null);
        $cursor = trim((string) ($queryParams['cursor'] ?? ''));

        if ($cursor !== '') {
            $query->where($query->getModel()->getTable().'.id', '>', $cursor);
        }

        $rows = $query->limit($limit + 1)->get()->all();
        $hasMore = count($rows) > $limit;
        $rows = array_slice($rows, 0, $limit);

        return [
            'data' => array_map($resource, $rows),
            'meta' => array_merge($meta, [
                'next_cursor' => $hasMore && $rows !== [] ? (string) $rows[array_key_last($rows)]->id : null,
                'has_more' => $hasMore,
            ]),
        ];
    }

    /**
     * @param array<int, array<string, mixed>> $rows
     * @param array<string, mixed> $queryParams
     * @param array<string, mixed> $meta
     * @return array{data: array<int, array<string, mixed>>, meta: array<string, mixed>}
     */
    private function paginateArray(array $rows, array $queryParams, array $meta = []): array
    {
        $limit = $this->limit($queryParams['limit'] ?? null);
        $cursor = trim((string) ($queryParams['cursor'] ?? ''));

        if ($cursor !== '') {
            $rows = array_values(array_filter($rows, fn (array $row): bool => strcmp((string) $row['id'], $cursor) > 0));
        }

        $pageRows = array_slice($rows, 0, $limit + 1);
        $hasMore = count($pageRows) > $limit;
        $pageRows = array_slice($pageRows, 0, $limit);

        return [
            'data' => $pageRows,
            'meta' => array_merge($meta, [
                'next_cursor' => $hasMore && $pageRows !== [] ? (string) $pageRows[array_key_last($pageRows)]['id'] : null,
                'has_more' => $hasMore,
            ]),
        ];
    }

    private function limit(mixed $value): int
    {
        return max(1, min(100, (int) ($value ?: 20)));
    }
}
