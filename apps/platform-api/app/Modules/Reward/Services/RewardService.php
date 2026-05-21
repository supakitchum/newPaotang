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
use App\Models\SyncOutbox;
use App\Models\Ticket;
use App\Models\Wallet;
use App\Models\WinningTicket;
use App\Shared\Audit\AuditLogger;
use App\Shared\Auth\AdminSessionContext;
use App\Modules\Auth\Services\CustomerAuthService;
use App\Shared\Auth\CustomerSessionContext;
use App\Modules\Commerce\Services\CommerceService;
use App\Shared\Idempotency\IdempotencyService;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Str;

class RewardService
{
    private const CHECK_CHUNK_SIZE = 100;
    public const CLAIM_PAYOUT_METHODS = ['wallet_credit', 'bank_transfer', 'manual_cash'];

    public function __construct(
        private readonly AuditLogger $auditLogger,
        private readonly IdempotencyService $idempotency,
        private readonly CustomerAuthService $customerAuth,
        private readonly CommerceService $commerce,
        private readonly TenantRewardPriceRuleService $tenantRewardPriceRules,
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

            if ($number === '' || str_starts_with($number, 'pending_')) {
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

            if ($number !== '' && ! str_starts_with($number, 'pending_') && isset($seen[$key])) {
                $errors["prizes.$index"][] = 'Duplicate prize rows are not allowed.';
            }

            if ($number !== '' && ! str_starts_with($number, 'pending_')) {
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

                        if ($normalizedNumber === '' || str_starts_with($normalizedNumber, 'pending_')) {
                            continue;
                        }

                        $hasUpdate = true;

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
            ],
        ];
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

            $version = max((int) $result->version, (int) RewardPublishLog::where('reward_result_id', $rewardResultId)->max('reward_version') + 1);
            $publishedAt = now();
            $summary = $this->summary($rewardResultId);
            $logId = 'rpl_'.Str::ulid()->toBase32();

            RewardResult::query()->where('id', $rewardResultId)->update([
                'status' => 'published',
                'version' => $version,
                'summary_json' => json_encode($summary, JSON_THROW_ON_ERROR),
                'published_by_admin_id' => $actor->adminUser['id'],
                'published_at' => $publishedAt,
                'updated_at' => $publishedAt,
            ]);
            RewardPublishLog::query()->insert([
                'id' => $logId,
                'reward_result_id' => $rewardResultId,
                'game_id' => (string) $result->game_id,
                'reward_version' => $version,
                'published_by_admin_id' => $actor->adminUser['id'],
                'payload_json' => json_encode($summary, JSON_THROW_ON_ERROR),
                'published_at' => $publishedAt,
                'created_at' => $publishedAt,
                'updated_at' => $publishedAt,
            ]);
            $this->setGameStatus((string) $result->game_id, 'reward_published');
            $this->insertOutboxEvent('reward.published.v1', (string) $result->game_id, 'reward_result', $rewardResultId, $request->header('Idempotency-Key'), $request->header('X-Request-Id'), [
                'reward_result_id' => $rewardResultId,
                'game_id' => (string) $result->game_id,
                'reward_version' => $version,
                'published_at' => $publishedAt->toISOString(),
            ]);

            return $this->rewardResult($rewardResultId) ?? [];
        }, 'reward.published');
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

        $winning = WinningTicket::query()
            ->join('reward_results', 'reward_results.id', '=', 'winning_tickets.reward_result_id')
            ->where('winning_tickets.tenant_id', $tenantId)
            ->where('winning_tickets.ticket_id', $ticketId)
            ->select('winning_tickets.*', 'reward_results.status as reward_result_status')
            ->orderByDesc('winning_tickets.created_at')
            ->first();
        $claim = RewardClaim::query()
            ->forTenant($tenantId)
            ->where('ticket_id', $ticketId)
            ->orderByDesc('created_at')
            ->first();

        if ($claim !== null) {
            return [
                'ticket_id' => $ticketId,
                'status' => $this->claimStatusForTicket((string) $claim->status),
                'claimable' => false,
                'prize_amount' => $this->money((int) $claim->prize_amount, (string) $claim->currency),
                'reward_result_id' => $winning?->reward_result_id,
                'reward_claim_id' => (string) $claim->id,
            ];
        }

        if ($winning !== null && in_array((string) $winning->reward_result_status, ['verified', 'published'], true)) {
            return [
                'ticket_id' => $ticketId,
                'status' => 'winning',
                'claimable' => (string) $winning->reward_result_status === 'published' && in_array((string) $winning->status, ['pending', 'verified'], true),
                'prize_amount' => $this->money((int) $winning->amount, (string) $winning->currency),
                'reward_result_id' => (string) $winning->reward_result_id,
                'reward_claim_id' => null,
            ];
        }

        if (RewardResult::where('game_id', $ticket->game_id)->where('status', 'published')->exists()) {
            return [
                'ticket_id' => $ticketId,
                'status' => 'non_winning',
                'claimable' => false,
                'prize_amount' => null,
                'reward_result_id' => null,
                'reward_claim_id' => null,
            ];
        }

        return [
            'ticket_id' => $ticketId,
            'status' => 'pending_result',
            'claimable' => false,
            'prize_amount' => null,
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
     * @return array{resource?: array<string, mixed>, status?: int, error?: string}
     */
    public function createCustomerClaim(string $tenantId, CustomerSessionContext $customer, array $payload, Request $request): array
    {
        $normalized = [
            'ticket_id' => trim((string) ($payload['ticket_id'] ?? '')),
            'payout_method' => trim((string) ($payload['payout_method'] ?? '')),
            'bank_account' => is_array($payload['bank_account'] ?? null) ? $payload['bank_account'] : null,
            'note' => trim((string) ($payload['note'] ?? '')),
        ];
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

            $ticket = Ticket::query()
                ->where('tenant_id', $tenantId)
                ->where('customer_id', $customer->customerId())
                ->where('id', $normalized['ticket_id'])
                ->lockForUpdate()
                ->first();

            if ($ticket === null) {
                return ['error' => 'not_found'];
            }

            $winning = WinningTicket::query()
                ->join('reward_results', 'reward_results.id', '=', 'winning_tickets.reward_result_id')
                ->where('winning_tickets.tenant_id', $tenantId)
                ->where('winning_tickets.ticket_id', $ticket->id)
                ->where('reward_results.status', 'published')
                ->select('winning_tickets.*')
                ->lockForUpdate()
                ->first();

            if ($winning === null || ! in_array((string) $winning->status, ['pending', 'verified'], true)) {
                return ['error' => 'resource_conflict'];
            }

            if (RewardClaim::where('tenant_id', $tenantId)->where('winning_ticket_id', $winning->id)->exists()) {
                return ['error' => 'resource_conflict'];
            }

            $walletId = null;

            if ($normalized['payout_method'] === 'wallet_credit') {
                $walletId = $this->customerAuth->ensurePrimaryWallet($tenantId, $customer->customerId());
            }

            $claimId = 'rcl_'.Str::ulid()->toBase32();
            $now = now();
            $priceRuleSnapshot = $winning->price_rule_snapshot_json;

            RewardClaim::query()->insert([
                'id' => $claimId,
                'tenant_id' => $tenantId,
                'customer_id' => $customer->customerId(),
                'ticket_id' => (string) $ticket->id,
                'winning_ticket_id' => (string) $winning->id,
                'game_id' => (string) $winning->game_id,
                'wallet_id' => $walletId,
                'reference' => 'RWD-'.strtoupper(substr($claimId, -10)),
                'status' => 'submitted',
                'payout_method' => $normalized['payout_method'],
                'prize_amount' => (int) $winning->amount,
                'base_prize_amount' => (int) ($winning->base_amount ?? $winning->amount),
                'adjustment_amount' => (int) ($winning->adjustment_amount ?? 0),
                'tenant_price_rule_id' => $winning->tenant_price_rule_id,
                'price_rule_snapshot_json' => is_array($priceRuleSnapshot) ? json_encode($priceRuleSnapshot, JSON_THROW_ON_ERROR) : $priceRuleSnapshot,
                'currency' => (string) $winning->currency,
                'bank_account_json' => $normalized['bank_account'] === null ? null : json_encode($normalized['bank_account'], JSON_THROW_ON_ERROR),
                'customer_note' => $payload['note'] ?? null,
                'idempotency_key' => $idempotencyKey,
                'payload_hash' => $this->idempotency->payloadHash($normalized),
                'submitted_at' => $now,
                'created_at' => $now,
                'updated_at' => $now,
            ]);

            $resource = $this->claimResource(RewardClaim::where('id', $claimId)->first());
            $this->idempotency->storeResponse($tenantId, 'customer', $customer->customerId(), $routeKey, $idempotencyKey, $normalized, 201, $resource);

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
            ->forTenant($tenantId)
            ->orderBy('id')
            ->limit($limit + 1);

        foreach (['status', 'game_id', 'customer_id'] as $field) {
            if (($queryParams[$field] ?? null) !== null && trim((string) $queryParams[$field]) !== '') {
                $query->where($field, trim((string) $queryParams[$field]));
            }
        }

        if (($queryParams['q'] ?? null) !== null && trim((string) $queryParams['q']) !== '') {
            $q = trim((string) $queryParams['q']);
            $query->where(function ($nested) use ($q): void {
                $nested->where('reference', 'like', '%'.$q.'%')
                    ->orWhere('ticket_id', 'like', '%'.$q.'%')
                    ->orWhere('customer_id', 'like', '%'.$q.'%');
            });
        }

        if (($queryParams['cursor'] ?? null) !== null && trim((string) $queryParams['cursor']) !== '') {
            $query->where('id', '>', trim((string) $queryParams['cursor']));
        }

        return $this->claimListResponse($query->get()->all(), $limit);
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
        return $this->tenantClaimWrite($tenantId, $actor, $claimId, $payload, $request, 'admin.tenant.reward_claims.approve', 'reward_claim.approve', 'reward_claim.approved', function (object $claim) use ($actor, $payload): array|string {
            if ((string) $claim->status === 'approved') {
                return [];
            }

            if (! in_array((string) $claim->status, ['submitted', 'under_review'], true)) {
                return 'resource_conflict';
            }

            $amount = $this->moneyAmount($payload['approved_amount'] ?? null, (int) $claim->prize_amount);

            if ($amount <= 0) {
                return 'resource_conflict';
            }

            RewardClaim::query()->where('id', $claim->id)->update([
                'status' => 'approved',
                'prize_amount' => $amount,
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
            $amount = $this->moneyAmount($payload['paid_amount'] ?? null, (int) $claim->prize_amount);
            $ledger = null;

            if (! in_array($method, self::CLAIM_PAYOUT_METHODS, true) || $amount <= 0) {
                return 'resource_conflict';
            }

            if ($method === 'wallet_credit') {
                $walletId = $claim->wallet_id ?? $this->customerAuth->ensurePrimaryWallet((string) $claim->tenant_id, (string) $claim->customer_id);
                $ledger = $this->commerce->postLedger((string) $claim->tenant_id, (string) $walletId, (string) $claim->customer_id, 'credit', $amount, 'reward_claim', (string) $claim->id, 'reward-pay-'.(string) $request->header('Idempotency-Key'), $actor->adminUser['id'], $payload);
                $this->insertWalletOutbox((string) $claim->tenant_id, (string) $claim->customer_id, (string) $walletId, $ledger, (string) $request->header('Idempotency-Key'), $request->header('X-Request-Id'));
            }

            RewardClaim::query()->where('id', $claim->id)->update([
                'status' => 'paid',
                'payout_method' => $method,
                'prize_amount' => $amount,
                'wallet_id' => $claim->wallet_id ?? ($method === 'wallet_credit' ? $ledger['wallet_id'] : null),
                'payout_ledger_id' => $ledger['id'] ?? null,
                'paid_by_admin_id' => $actor->adminUser['id'],
                'paid_at' => now(),
                'admin_note' => $payload['reason'] ?? null,
                'updated_at' => now(),
            ]);
            WinningTicket::query()->where('id', $claim->winning_ticket_id)->update(['status' => 'paid', 'updated_at' => now()]);
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
                    ->get(['id'])
                    ->all();

                foreach ($update['prize_numbers'] as $index => $number) {
                    if (! isset($rows[$index]) || $number === '' || str_starts_with($number, 'pending_')) {
                        continue;
                    }

                    RewardPrize::query()->where('id', $rows[$index]->id)->update([
                        'prize_number' => $number,
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
                if (! isset($indexes[$index]) || $number === '' || str_starts_with($number, 'pending_')) {
                    continue;
                }

                $rows[$indexes[$index]]['prize_number'] = $number;
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
            'amount' => $this->money((int) $prize->amount, (string) $prize->currency),
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
            'game_id' => (string) $result->game_id,
            'reward_version' => (int) $result->version,
            'status' => (string) $result->status,
            'prizes' => array_map(function (object $prize): array {
                $winningCount = WinningTicket::where('reward_prize_id', $prize->id)->count();

                return $this->prizeResource($prize) + [
                    'winning_count' => $winningCount,
                    'total_amount' => $this->money($winningCount * (int) $prize->amount, (string) $prize->currency),
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

        return [
            'game_id' => (string) $result->game_id,
            'reward_version' => (int) $result->version,
            'status' => (string) $result->status,
            'prizes' => $summary['prizes'] ?? array_map(fn (object $prize): array => $this->prizeResource($prize), RewardPrize::query()->where('reward_result_id', $result->id)->orderBy('sort_order')->get()->all()),
        ];
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
     * @return array<string, mixed>
     */
    private function claimResource(object $claim): array
    {
        $ticket = Ticket::where('id', $claim->ticket_id)->first();
        $customer = Customer::where('id', $claim->customer_id)->first();
        $winning = WinningTicket::where('id', $claim->winning_ticket_id)->first();
        $wallet = $claim->wallet_id === null ? null : Wallet::where('id', $claim->wallet_id)->first();

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
            'prize_amount' => $this->money((int) $claim->prize_amount, (string) $claim->currency),
            'reward_pricing' => [
                'base_source' => TenantRewardPriceRuleService::BASE_SOURCE_CENTRAL_REWARD,
                'base_prize_amount' => $this->money((int) ($claim->base_prize_amount ?? $claim->prize_amount), (string) $claim->currency),
                'adjustment_amount' => $this->money((int) ($claim->adjustment_amount ?? 0), (string) $claim->currency),
                'effective_prize_amount' => $this->money((int) $claim->prize_amount, (string) $claim->currency),
                'tenant_price_rule_id' => $claim->tenant_price_rule_id,
                'price_rule_snapshot' => $this->decodeJsonObject($claim->price_rule_snapshot_json),
            ],
            'status' => (string) $claim->status,
            'payout_method' => $claim->payout_method,
            'payout_wallet' => $wallet === null ? null : $this->walletResource($wallet),
            'submitted_at' => $claim->submitted_at,
            'reviewed_at' => $claim->reviewed_at,
            'paid_at' => $claim->paid_at,
            'admin_note' => $claim->admin_note,
            'created_at' => $claim->created_at,
        ];
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
        Game::query()->whereKey($gameId)->update([
            'status' => $status,
            'updated_at' => now(),
        ]);
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

    private function claimStatusForTicket(string $claimStatus): string
    {
        return match ($claimStatus) {
            'submitted', 'under_review' => 'claim_submitted',
            'approved' => 'approved',
            'paid' => 'paid_out',
            'rejected', 'cancelled' => 'winning',
            default => 'pending_result',
        };
    }

    private function customerProfile(object $customer): array
    {
        return [
            'id' => (string) $customer->id,
            'tenant_id' => (string) $customer->tenant_id,
            'name' => $customer->name,
            'phone' => $customer->phone,
            'email' => $customer->email ?? null,
            'status' => $customer->status ?? null,
            'avatar_url' => $customer->avatar_url ?? null,
        ];
    }

    private function ticketResource(object $ticket): array
    {
        return [
            'id' => (string) $ticket->id,
            'game_id' => (string) $ticket->game_id,
            'full_number' => (string) $ticket->full_number,
            'status' => (string) $ticket->status,
            'image_thumb_url' => $ticket->image_thumb_url,
            'image_url' => $ticket->image_url,
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
}
