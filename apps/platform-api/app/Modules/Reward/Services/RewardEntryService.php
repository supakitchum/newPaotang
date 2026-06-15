<?php

namespace App\Modules\Reward\Services;

use App\Models\AdminUserRole;
use App\Models\Game;
use App\Models\RewardEntryResolution;
use App\Models\RewardEntrySession;
use App\Models\RewardEntrySubmission;
use App\Models\RewardPrize;
use App\Models\RewardResult;
use App\Modules\Rbac\Events\AdminMenuBadgesUpdated;
use App\Shared\Audit\AuditLogger;
use App\Shared\Auth\AdminSessionContext;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Str;

class RewardEntryService
{
    private const SESSION_STATUSES = ['collecting', 'ready_for_owner', 'resolved', 'cancelled'];
    private const ELIGIBLE_GAME_STATUSES = ['closed', 'reward_recorded', 'reward_checking', 'reward_verified'];
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

    public function __construct(
        private readonly RewardService $rewards,
        private readonly AuditLogger $auditLogger,
    ) {
    }

    /**
     * @param array<string, mixed> $query
     * @return array<string, mixed>
     */
    public function currentSession(array $query, AdminSessionContext $actor): array
    {
        $game = $this->resolveGame($query['game_id'] ?? null);

        if ($game === null) {
            return [
                'data' => null,
                'meta' => [
                    'status' => 'no_eligible_game',
                    'message' => 'No closed game is waiting for reward entry.',
                    'template_prizes' => $this->emptyPrizeRows(),
                    'prize_definitions' => $this->prizeDefinitions(),
                ],
            ];
        }

        $session = $this->findOrCreateSession((string) $game->id, $actor);
        $session = $this->refreshScraperSnapshot($session);

        return [
            'data' => $this->sessionResource($session, $actor),
            'meta' => [
                'status' => (int) $session->expected_operator_count > 0 ? 'ready' : 'setup_required',
                'template_prizes' => $this->emptyPrizeRows(),
                'prize_definitions' => $this->prizeDefinitions(),
            ],
        ];
    }

    /**
     * @return array<string, mixed>|null
     */
    public function session(string $sessionId, AdminSessionContext $actor): ?array
    {
        $session = RewardEntrySession::query()
            ->with(['game', 'resolution'])
            ->whereKey($sessionId)
            ->first();

        return $session === null ? null : $this->sessionResource($this->refreshScraperSnapshot($session), $actor);
    }

    /**
     * @param array<string, mixed> $payload
     * @return array{resource?: array<string, mixed>, error?: string, errors?: array<string, array<int, string>>}
     */
    public function saveSubmission(string $sessionId, array $payload, AdminSessionContext $actor, Request $request): array
    {
        return DB::transaction(function () use ($sessionId, $payload, $actor, $request): array {
            $session = RewardEntrySession::query()->whereKey($sessionId)->lockForUpdate()->first();

            if ($session === null) {
                return ['error' => 'not_found'];
            }

            if (! in_array((string) $session->status, ['collecting', 'ready_for_owner'], true)) {
                return ['error' => 'resource_conflict'];
            }

            if (! $this->actorIsExpectedOperator($session, $actor)) {
                return ['error' => 'permission_denied'];
            }

            $submission = $this->submissionForActor($session, $actor, true);

            if ((string) $submission->status === 'submitted') {
                return ['error' => 'resource_conflict'];
            }

            $prizes = $this->normalizePrizeRows($payload['prizes'] ?? []);
            $now = now();

            RewardEntrySubmission::query()->whereKey($submission->id)->update([
                'prizes_json' => $this->jsonValue($prizes),
                'status' => 'draft',
                'diff_to_scraper_json' => null,
                'updated_at' => $now,
            ]);

            $this->audit($actor, $request, 'reward_entry.draft_saved', 'reward_entry_submission', (string) $submission->id, [
                'session_id' => (string) $session->id,
                'game_id' => (string) $session->game_id,
            ]);

            $fresh = RewardEntrySession::query()->whereKey($session->id)->first() ?? $session;

            return ['resource' => $this->sessionResource($fresh, $actor)];
        });
    }

    /**
     * @param array<string, mixed> $payload
     * @return array{resource?: array<string, mixed>, error?: string, errors?: array<string, array<int, string>>}
     */
    public function submitSubmission(string $sessionId, array $payload, AdminSessionContext $actor, Request $request): array
    {
        return DB::transaction(function () use ($sessionId, $payload, $actor, $request): array {
            $session = RewardEntrySession::query()->whereKey($sessionId)->lockForUpdate()->first();

            if ($session === null) {
                return ['error' => 'not_found'];
            }

            if (! in_array((string) $session->status, ['collecting', 'ready_for_owner'], true)) {
                return ['error' => 'resource_conflict'];
            }

            if (! $this->actorIsExpectedOperator($session, $actor)) {
                return ['error' => 'permission_denied'];
            }

            $submission = $this->submissionForActor($session, $actor, true);

            if ((string) $submission->status === 'submitted') {
                return ['resource' => $this->sessionResource($this->refreshScraperSnapshot($session), $actor), 'status' => 200];
            }

            $prizes = array_key_exists('prizes', $payload)
                ? $this->normalizePrizeRows($payload['prizes'])
                : $this->normalizePrizeRows($submission->prizes_json ?? []);

            $errors = $this->rewards->validateRewardPayload([
                'game_id' => (string) $session->game_id,
                'prizes' => $prizes,
            ]);

            if ($errors !== []) {
                return ['error' => 'validation_failed', 'errors' => $errors];
            }

            $session = $this->refreshScraperSnapshot($session, true);
            $diff = $this->diffToScraper($prizes, $session->scraper_snapshot_json ?? null);
            $now = now();

            RewardEntrySubmission::query()->whereKey($submission->id)->update([
                'status' => 'submitted',
                'prizes_json' => $this->jsonValue($prizes),
                'diff_to_scraper_json' => $this->jsonValue($diff),
                'submitted_at' => $now,
                'updated_at' => $now,
            ]);

            $submittedCount = RewardEntrySubmission::query()
                ->where('session_id', $session->id)
                ->where('status', 'submitted')
                ->count();

            $nextStatus = (int) $session->expected_operator_count > 0
                && $submittedCount >= (int) $session->expected_operator_count
                    ? 'ready_for_owner'
                    : (string) $session->status;

            RewardEntrySession::query()->whereKey($session->id)->update([
                'status' => $nextStatus,
                'submitted_count' => $submittedCount,
                'ready_at' => $nextStatus === 'ready_for_owner' && $session->ready_at === null ? $now : $session->ready_at,
                'updated_at' => $now,
            ]);

            $this->audit($actor, $request, 'reward_entry.submitted', 'reward_entry_submission', (string) $submission->id, [
                'session_id' => (string) $session->id,
                'game_id' => (string) $session->game_id,
                'matches_scraper' => $diff['summary']['mismatch_count'] === 0,
                'mismatch_count' => $diff['summary']['mismatch_count'],
            ]);
            $this->queueCentralMenuBadgeBroadcast('reward_entry');

            $fresh = RewardEntrySession::query()->whereKey($session->id)->first() ?? $session;

            return ['resource' => $this->sessionResource($fresh, $actor), 'status' => 202];
        });
    }

    /**
     * @return array<string, mixed>
     */
    public function ownerQueue(): array
    {
        $sessions = RewardEntrySession::query()
            ->with(['game', 'resolution'])
            ->whereIn('status', self::SESSION_STATUSES)
            ->orderByRaw("case status when 'ready_for_owner' then 0 when 'collecting' then 1 when 'resolved' then 2 else 3 end")
            ->orderByDesc('updated_at')
            ->limit(100)
            ->get()
            ->all();

        return [
            'data' => array_map(fn (object $session): array => $this->sessionSummaryResource($session), $sessions),
            'meta' => ['next_cursor' => null, 'has_more' => false],
        ];
    }

    /**
     * @return array<string, mixed>|null
     */
    public function comparison(string $sessionId): ?array
    {
        $session = RewardEntrySession::query()
            ->with(['game', 'resolution'])
            ->whereKey($sessionId)
            ->first();

        if ($session === null) {
            return null;
        }

        $session = $this->refreshScraperSnapshot($session);

        $submissions = RewardEntrySubmission::query()
            ->where('session_id', $session->id)
            ->where('status', 'submitted')
            ->orderBy('submitted_at')
            ->get()
            ->all();

        $sources = $this->comparisonSources($session, $submissions);

        return [
            'data' => [
                'session' => $this->sessionSummaryResource($session),
                'sources' => $sources,
                'matrix' => $this->comparisonMatrix($sources),
                'template_prizes' => $this->emptyPrizeRows(),
                'prize_definitions' => $this->prizeDefinitions(),
            ],
        ];
    }

    /**
     * @param array<string, mixed> $payload
     * @return array{resource?: array<string, mixed>, status?: int, error?: string, errors?: array<string, array<int, string>>}
     */
    public function resolve(string $sessionId, array $payload, AdminSessionContext $actor, Request $request): array
    {
        return DB::transaction(function () use ($sessionId, $payload, $actor, $request): array {
            $session = RewardEntrySession::query()->whereKey($sessionId)->lockForUpdate()->first();

            if ($session === null) {
                return ['error' => 'not_found'];
            }

            if ((string) $session->status !== 'ready_for_owner') {
                return ['error' => 'resource_conflict'];
            }

            $session = $this->refreshScraperSnapshot($session, true);

            $selectedSourceType = trim((string) ($payload['selected_source_type'] ?? 'manual'));
            $selectedSubmissionId = trim((string) ($payload['selected_submission_id'] ?? '')) ?: null;
            $reason = trim((string) ($payload['reason'] ?? ''));
            $finalPrizes = array_key_exists('final_prizes', $payload)
                ? $this->normalizePrizeRows($payload['final_prizes'])
                : $this->sourcePrizes($session, $selectedSourceType, $selectedSubmissionId);

            if (! in_array($selectedSourceType, ['scraper', 'submission', 'manual'], true)) {
                return ['error' => 'validation_failed', 'errors' => ['selected_source_type' => ['The selected source type is invalid.']]];
            }

            if ($selectedSourceType === 'submission' && ! $this->submittedSourceExists($session, $selectedSubmissionId)) {
                return ['error' => 'validation_failed', 'errors' => ['selected_submission_id' => ['The selected submission must belong to this session and be submitted.']]];
            }

            if ($selectedSourceType === 'scraper' && ! is_array($session->scraper_snapshot_json ?? null)) {
                return ['error' => 'validation_failed', 'errors' => ['selected_source_type' => ['A lotto-scraper snapshot is not available for this session.']]];
            }

            if ($finalPrizes === []) {
                return ['error' => 'validation_failed', 'errors' => ['final_prizes' => ['The final prizes field is required.']]];
            }

            if ($reason === '') {
                return ['error' => 'validation_failed', 'errors' => ['reason' => ['The reason field is required before resolving reward entry.']]];
            }

            $errors = $this->rewards->validateRewardPayload([
                'game_id' => (string) $session->game_id,
                'prizes' => $finalPrizes,
            ]);

            if ($errors !== []) {
                return ['error' => 'validation_failed', 'errors' => $errors];
            }

            $result = $this->rewards->createRewardResult([
                'game_id' => (string) $session->game_id,
                'prizes' => $finalPrizes,
            ], $actor, $request);

            if (isset($result['error'])) {
                return $result;
            }

            $rewardResultId = (string) (($result['resource']['id'] ?? null) ?: RewardResult::query()
                ->where('game_id', $session->game_id)
                ->value('id'));
            $resolutionId = 'ren_'.Str::ulid()->toBase32();
            $now = now();

            RewardEntryResolution::query()->insert([
                'id' => $resolutionId,
                'session_id' => (string) $session->id,
                'game_id' => (string) $session->game_id,
                'reward_result_id' => $rewardResultId,
                'selected_source_type' => $selectedSourceType,
                'selected_submission_id' => $selectedSubmissionId,
                'final_prizes_json' => $this->jsonValue($finalPrizes),
                'reason' => $reason,
                'resolved_by_admin_id' => $actor->adminUser['id'],
                'resolved_at' => $now,
                'created_at' => $now,
                'updated_at' => $now,
            ]);

            RewardEntrySession::query()->whereKey($session->id)->update([
                'status' => 'resolved',
                'reward_result_id' => $rewardResultId,
                'resolved_by_admin_id' => $actor->adminUser['id'],
                'resolved_at' => $now,
                'updated_at' => $now,
            ]);

            $this->audit($actor, $request, 'reward_entry.resolved', 'reward_entry_session', (string) $session->id, [
                'game_id' => (string) $session->game_id,
                'reward_result_id' => $rewardResultId,
                'selected_source_type' => $selectedSourceType,
                'selected_submission_id' => $selectedSubmissionId,
                'reason' => $reason,
            ]);
            $this->queueCentralMenuBadgeBroadcast('reward_entry');

            $fresh = RewardEntrySession::query()->whereKey($session->id)->first() ?? $session;

            return [
                'resource' => $this->sessionResource($fresh, $actor) + [
                    'reward_result' => $result['resource'] ?? null,
                ],
                'status' => 202,
            ];
        });
    }

    /**
     * @param mixed $gameId
     */
    private function resolveGame(mixed $gameId): ?object
    {
        $trimmedGameId = trim((string) ($gameId ?? ''));

        $query = Game::query()
            ->whereIn('status', self::ELIGIBLE_GAME_STATUSES)
            ->orderByDesc('draw_at')
            ->orderByDesc('created_at');

        if ($trimmedGameId !== '') {
            $query->whereKey($trimmedGameId);
        }

        return $query->first();
    }

    private function findOrCreateSession(string $gameId, AdminSessionContext $actor): object
    {
        return DB::transaction(function () use ($gameId, $actor): object {
            $existing = RewardEntrySession::query()->where('game_id', $gameId)->lockForUpdate()->first();

            if ($existing !== null) {
                return $existing;
            }

            $operators = $this->resultOfficerSnapshot();
            $now = now();

            RewardEntrySession::query()->insert([
                'id' => 'res_'.Str::ulid()->toBase32(),
                'game_id' => $gameId,
                'status' => 'collecting',
                'expected_operators_json' => $this->jsonValue($operators),
                'expected_operator_count' => count($operators),
                'submitted_count' => 0,
                'scraper_snapshot_json' => $this->jsonValue($this->scraperSnapshotForGame($gameId)),
                'created_by_admin_id' => $actor->adminUser['id'],
                'created_at' => $now,
                'updated_at' => $now,
            ]);

            return RewardEntrySession::query()->where('game_id', $gameId)->firstOrFail();
        });
    }

    private function refreshScraperSnapshot(object $session, bool $refreshSubmittedDiffs = true): object
    {
        if (in_array((string) $session->status, ['resolved', 'cancelled'], true)) {
            return $session;
        }

        $snapshot = $this->scraperSnapshotForGame((string) $session->game_id);

        if ($snapshot === null) {
            return $session;
        }

        $current = is_array($session->scraper_snapshot_json ?? null) ? $session->scraper_snapshot_json : null;
        $snapshotChanged = $this->scraperSnapshotKey($current) !== $this->scraperSnapshotKey($snapshot);

        if (! $snapshotChanged) {
            return $session;
        }

        $now = now();

        RewardEntrySession::query()->whereKey($session->id)->update([
            'scraper_snapshot_json' => $this->jsonValue($snapshot),
            'updated_at' => $now,
        ]);

        if ($refreshSubmittedDiffs) {
            $submissions = RewardEntrySubmission::query()
                ->where('session_id', $session->id)
                ->where('status', 'submitted')
                ->get(['id', 'prizes_json'])
                ->all();

            foreach ($submissions as $submission) {
                RewardEntrySubmission::query()->whereKey($submission->id)->update([
                    'diff_to_scraper_json' => $this->jsonValue($this->diffToScraper(
                        $this->normalizePrizeRows($submission->prizes_json ?? []),
                        $snapshot,
                    )),
                    'updated_at' => $now,
                ]);
            }
        }

        return RewardEntrySession::query()->with(['game', 'resolution'])->whereKey($session->id)->first() ?? $session;
    }

    private function scraperSnapshotKey(?array $snapshot): string
    {
        if ($snapshot === null) {
            return '';
        }

        $source = is_array($snapshot['source'] ?? null) ? $snapshot['source'] : [];
        $live = is_array($snapshot['live'] ?? null) ? $snapshot['live'] : [];

        return implode('|', [
            (string) ($snapshot['reward_result_id'] ?? ''),
            (string) ($source['payload_hash'] ?? ''),
            (string) ($live['completion_percent'] ?? ''),
            (string) ($snapshot['updated_at'] ?? ''),
        ]);
    }

    private function queueCentralMenuBadgeBroadcast(string $source): void
    {
        if (DB::transactionLevel() > 0) {
            DB::afterCommit(fn (): mixed => AdminMenuBadgesUpdated::dispatch('central', null, $source));

            return;
        }

        AdminMenuBadgesUpdated::dispatch('central', null, $source);
    }

    /**
     * @return array<int, array{id: string, name: string, email: string, username: string|null}>
     */
    private function resultOfficerSnapshot(): array
    {
        return AdminUserRole::query()
            ->with('adminUser')
            ->whereHas('role', function ($query): void {
                $query
                    ->where('scope_type', 'central')
                    ->whereNull('tenant_id')
                    ->where('code', 'result_officer')
                    ->where('status', 'active');
            })
            ->whereHas('scope', function ($query): void {
                $query->where('scope_type', 'central');
            })
            ->whereHas('adminUser', function ($query): void {
                $query->where('status', 'active');
            })
            ->get()
            ->map(fn (AdminUserRole $assignment): ?array => $assignment->adminUser === null ? null : [
                'id' => (string) $assignment->adminUser->id,
                'name' => trim((string) ($assignment->adminUser->name ?: $assignment->adminUser->email)),
                'email' => (string) $assignment->adminUser->email,
                'username' => $assignment->adminUser->username === null ? null : (string) $assignment->adminUser->username,
            ])
            ->filter()
            ->unique('id')
            ->sortBy('email')
            ->values()
            ->all();
    }

    private function actorIsExpectedOperator(object $session, AdminSessionContext $actor): bool
    {
        return in_array((string) $actor->adminUser['id'], $this->expectedOperatorIds($session), true);
    }

    /**
     * @return array<int, string>
     */
    private function expectedOperatorIds(object $session): array
    {
        $operators = is_array($session->expected_operators_json ?? null) ? $session->expected_operators_json : [];

        return array_values(array_filter(array_map(
            fn (mixed $operator): string => is_array($operator) ? (string) ($operator['id'] ?? '') : '',
            $operators,
        )));
    }

    private function submissionForActor(object $session, AdminSessionContext $actor, bool $create): object
    {
        $submission = RewardEntrySubmission::query()
            ->where('session_id', $session->id)
            ->where('admin_user_id', $actor->adminUser['id'])
            ->first();

        if ($submission !== null || ! $create) {
            return $submission;
        }

        $now = now();
        $id = 'ret_'.Str::ulid()->toBase32();

        RewardEntrySubmission::query()->insert([
            'id' => $id,
            'session_id' => (string) $session->id,
            'game_id' => (string) $session->game_id,
            'admin_user_id' => $actor->adminUser['id'],
            'status' => 'draft',
            'prizes_json' => $this->jsonValue($this->emptyPrizeRows()),
            'created_at' => $now,
            'updated_at' => $now,
        ]);

        return RewardEntrySubmission::query()->whereKey($id)->firstOrFail();
    }

    /**
     * @return array<string, mixed>|null
     */
    private function scraperSnapshotForGame(string $gameId): ?array
    {
        $result = RewardResult::query()
            ->where('game_id', $gameId)
            ->where('status', 'draft')
            ->orderByDesc('updated_at')
            ->first();

        if ($result === null) {
            return null;
        }

        $summary = is_array($result->summary_json) ? $result->summary_json : [];

        return [
            'reward_result_id' => (string) $result->id,
            'status' => (string) $result->status,
            'source' => $summary['source'] ?? ['name' => 'lotto-scraper'],
            'live' => $summary['live'] ?? null,
            'updated_at' => optional($result->updated_at)->toISOString(),
            'prizes' => $this->rewardPrizeRows((string) $result->id),
        ];
    }

    /**
     * @return array<int, array<string, mixed>>
     */
    private function rewardPrizeRows(string $rewardResultId): array
    {
        return array_map(fn (object $prize): array => [
            'prize_type' => (string) $prize->prize_type,
            'prize_number' => (string) $prize->prize_number,
            'amount' => [
                'amount' => (int) $prize->amount,
                'currency' => (string) $prize->currency,
            ],
        ], RewardPrize::query()
            ->where('reward_result_id', $rewardResultId)
            ->orderBy('sort_order')
            ->orderBy('id')
            ->get()
            ->all());
    }

    /**
     * @param mixed $value
     * @return array<int, array<string, mixed>>
     */
    private function normalizePrizeRows(mixed $value): array
    {
        $rules = ThaiGovernmentLotteryRewardTemplate::rules();
        $rowsByType = [];
        $input = is_array($value) ? array_values($value) : [];

        foreach ($input as $row) {
            if (! is_array($row)) {
                continue;
            }

            $type = trim((string) ($row['prize_type'] ?? $row['type'] ?? ''));
            if (! isset($rules[$type])) {
                continue;
            }

            if (array_key_exists('prize_numbers', $row) && is_array($row['prize_numbers'])) {
                foreach ($row['prize_numbers'] as $number) {
                    $rowsByType[$type][] = trim((string) $number);
                }
                continue;
            }

            if (array_key_exists('numbers', $row) && is_array($row['numbers'])) {
                foreach ($row['numbers'] as $number) {
                    $rowsByType[$type][] = trim((string) $number);
                }
                continue;
            }

            $rowsByType[$type][] = trim((string) ($row['prize_number'] ?? ''));
        }

        $normalized = [];
        foreach ($rules as $type => $rule) {
            $numbers = array_values($rowsByType[$type] ?? []);
            for ($index = 0; $index < (int) $rule['count']; $index++) {
                $normalized[] = [
                    'prize_type' => $type,
                    'prize_number' => trim((string) ($numbers[$index] ?? '')),
                    'amount' => [
                        'amount' => (int) $rule['amount'],
                        'currency' => ThaiGovernmentLotteryRewardTemplate::CURRENCY,
                    ],
                ];
            }
        }

        return $normalized;
    }

    /**
     * @return array<int, array<string, mixed>>
     */
    private function emptyPrizeRows(): array
    {
        return $this->normalizePrizeRows([]);
    }

    /**
     * @return array<int, array<string, mixed>>
     */
    private function prizeDefinitions(): array
    {
        $labels = [
            'first_prize' => 'รางวัลที่ 1',
            'near_first_prize' => 'รางวัลข้างเคียงรางวัลที่ 1',
            'second_prize' => 'รางวัลที่ 2',
            'third_prize' => 'รางวัลที่ 3',
            'fourth_prize' => 'รางวัลที่ 4',
            'fifth_prize' => 'รางวัลที่ 5',
            'front3' => 'เลขหน้า 3 ตัว',
            'back3' => 'เลขท้าย 3 ตัว',
            'back2' => 'เลขท้าย 2 ตัว',
        ];

        return array_map(fn (string $type, array $rule): array => [
            'type' => $type,
            'label' => $labels[$type] ?? $type,
            'count' => (int) $rule['count'],
            'digits' => (int) $rule['digits'],
            'amount' => (int) $rule['amount'],
            'currency' => ThaiGovernmentLotteryRewardTemplate::CURRENCY,
        ], array_keys(ThaiGovernmentLotteryRewardTemplate::rules()), ThaiGovernmentLotteryRewardTemplate::rules());
    }

    /**
     * @param array<int, array<string, mixed>> $prizes
     * @param array<string, mixed>|null $scraperSnapshot
     * @return array<string, mixed>
     */
    private function diffToScraper(array $prizes, ?array $scraperSnapshot): array
    {
        $scraperPrizes = $this->normalizePrizeRows($scraperSnapshot['prizes'] ?? []);
        $rows = [];
        $mismatchCount = 0;
        $missingScraperCount = 0;

        foreach ($this->indexedRows($prizes) as $key => $row) {
            $scraper = $this->indexedRows($scraperPrizes)[$key] ?? null;
            $scraperNumber = $scraper === null ? null : trim((string) $scraper['prize_number']);
            $operatorNumber = trim((string) $row['prize_number']);
            $matches = $scraperNumber !== null && $scraperNumber !== '' && $operatorNumber === $scraperNumber;

            if ($scraperNumber === null || $scraperNumber === '') {
                $missingScraperCount++;
            } elseif (! $matches) {
                $mismatchCount++;
            }

            $rows[] = [
                'key' => $key,
                'prize_type' => (string) $row['prize_type'],
                'index' => $this->rowIndexFromKey($key),
                'operator_number' => $operatorNumber,
                'scraper_number' => $scraperNumber,
                'matches' => $matches,
            ];
        }

        return [
            'summary' => [
                'has_scraper' => $scraperSnapshot !== null,
                'mismatch_count' => $mismatchCount,
                'missing_scraper_count' => $missingScraperCount,
            ],
            'rows' => $rows,
        ];
    }

    /**
     * @param array<int, array<string, mixed>> $prizes
     * @return array<string, array<string, mixed>>
     */
    private function indexedRows(array $prizes): array
    {
        $counters = [];
        $indexed = [];

        foreach ($this->normalizePrizeRows($prizes) as $row) {
            $type = (string) $row['prize_type'];
            $index = $counters[$type] ?? 0;
            $indexed[$type.':'.$index] = $row;
            $counters[$type] = $index + 1;
        }

        return $indexed;
    }

    private function rowIndexFromKey(string $key): int
    {
        $parts = explode(':', $key);

        return (int) ($parts[1] ?? 0);
    }

    /**
     * @param array<int, object> $submissions
     * @return array<int, array<string, mixed>>
     */
    private function comparisonSources(object $session, array $submissions): array
    {
        $sources = [];
        $snapshot = is_array($session->scraper_snapshot_json ?? null) ? $session->scraper_snapshot_json : null;

        if ($snapshot !== null) {
            $sources[] = [
                'id' => 'scraper',
                'source_type' => 'scraper',
                'label' => 'Lotto Scraper',
                'submitted_at' => $snapshot['updated_at'] ?? null,
                'prizes' => $this->normalizePrizeRows($snapshot['prizes'] ?? []),
                'meta' => [
                    'source' => $snapshot['source'] ?? null,
                    'live' => $snapshot['live'] ?? null,
                ],
            ];
        }

        $operators = collect(is_array($session->expected_operators_json ?? null) ? $session->expected_operators_json : [])
            ->keyBy('id');

        foreach ($submissions as $submission) {
            $operator = $operators->get((string) $submission->admin_user_id, []);
            $label = trim((string) (($operator['name'] ?? '') ?: ($operator['email'] ?? $submission->admin_user_id)));
            $sources[] = [
                'id' => (string) $submission->id,
                'source_type' => 'submission',
                'label' => $label,
                'admin_user_id' => (string) $submission->admin_user_id,
                'submitted_at' => $submission->submitted_at,
                'prizes' => $this->normalizePrizeRows($submission->prizes_json ?? []),
                'diff_to_scraper' => $submission->diff_to_scraper_json,
            ];
        }

        return $sources;
    }

    /**
     * @param array<int, array<string, mixed>> $sources
     * @return array<int, array<string, mixed>>
     */
    private function comparisonMatrix(array $sources): array
    {
        $matrix = [];
        $empty = $this->emptyPrizeRows();

        foreach ($this->indexedRows($empty) as $key => $row) {
            $values = [];
            foreach ($sources as $source) {
                $indexed = $this->indexedRows($source['prizes'] ?? []);
                $values[] = [
                    'source_id' => $source['id'],
                    'source_type' => $source['source_type'],
                    'number' => (string) (($indexed[$key]['prize_number'] ?? '') ?: ''),
                ];
            }

            $numbers = array_values(array_unique(array_filter(array_map(
                fn (array $value): string => trim((string) $value['number']),
                $values,
            ), fn (string $number): bool => $number !== '')));

            $matrix[] = [
                'key' => $key,
                'prize_type' => (string) $row['prize_type'],
                'index' => $this->rowIndexFromKey($key),
                'values' => $values,
                'all_match' => count($numbers) <= 1 && count($numbers) > 0,
            ];
        }

        return $matrix;
    }

    /**
     * @return array<int, array<string, mixed>>
     */
    private function sourcePrizes(object $session, string $sourceType, ?string $submissionId): array
    {
        if ($sourceType === 'scraper') {
            $snapshot = is_array($session->scraper_snapshot_json ?? null) ? $session->scraper_snapshot_json : null;

            return $this->normalizePrizeRows($snapshot['prizes'] ?? []);
        }

        if ($sourceType === 'submission' && $submissionId !== null) {
            $submission = RewardEntrySubmission::query()
                ->where('session_id', $session->id)
                ->where('status', 'submitted')
                ->whereKey($submissionId)
                ->first();

            return $submission === null ? [] : $this->normalizePrizeRows($submission->prizes_json ?? []);
        }

        return [];
    }

    private function submittedSourceExists(object $session, ?string $submissionId): bool
    {
        if ($submissionId === null || trim($submissionId) === '') {
            return false;
        }

        return RewardEntrySubmission::query()
            ->where('session_id', $session->id)
            ->where('status', 'submitted')
            ->whereKey($submissionId)
            ->exists();
    }

    /**
     * @return array<string, mixed>
     */
    private function sessionResource(object $session, AdminSessionContext $actor): array
    {
        $session = $this->refreshScraperSnapshot($session);
        $session = RewardEntrySession::query()->with(['game', 'resolution'])->whereKey($session->id)->first() ?? $session;
        $submission = $this->actorIsExpectedOperator($session, $actor)
            ? $this->submissionForActor($session, $actor, true)
            : null;

        return [
            'id' => (string) $session->id,
            'status' => (string) $session->status,
            'game' => $this->gameResource($session->game),
            'expected_operator_count' => (int) $session->expected_operator_count,
            'submitted_count' => (int) $session->submitted_count,
            'expected_operators' => $session->expected_operators_json ?? [],
            'is_expected_operator' => $submission !== null,
            'submission' => $submission === null ? null : [
                'id' => (string) $submission->id,
                'status' => (string) $submission->status,
                'prizes' => $this->normalizePrizeRows($submission->prizes_json ?? []),
                'diff_to_scraper' => (string) $submission->status === 'submitted' ? $submission->diff_to_scraper_json : null,
                'submitted_at' => $submission->submitted_at,
            ],
            'scraper_snapshot' => $this->scraperSnapshotForResponse($session, $submission),
            'reward_result_id' => $session->reward_result_id,
            'ready_at' => $session->ready_at,
            'resolved_at' => $session->resolved_at,
            'resolution' => $this->resolutionResource($session->resolution),
        ];
    }

    /**
     * @return array<string, mixed>
     */
    private function sessionSummaryResource(object $session): array
    {
        $session = $this->refreshScraperSnapshot($session);
        $session = RewardEntrySession::query()->with(['game', 'resolution'])->whereKey($session->id)->first() ?? $session;

        return [
            'id' => (string) $session->id,
            'status' => (string) $session->status,
            'game' => $this->gameResource($session->game),
            'expected_operator_count' => (int) $session->expected_operator_count,
            'submitted_count' => (int) $session->submitted_count,
            'has_scraper_snapshot' => is_array($session->scraper_snapshot_json ?? null),
            'ready_at' => $session->ready_at,
            'resolved_at' => $session->resolved_at,
            'reward_result_id' => $session->reward_result_id,
            'resolution' => $this->resolutionResource($session->resolution),
        ];
    }

    /**
     * @return array<string, mixed>|null
     */
    private function gameResource(?object $game): ?array
    {
        if ($game === null) {
            return null;
        }

        return [
            'id' => (string) $game->id,
            'code' => (string) $game->code,
            'name' => (string) $game->name,
            'status' => (string) $game->status,
            'draw_at' => $game->draw_at,
            'close_at' => $game->close_at,
            'closed_at' => $game->closed_at,
        ];
    }

    /**
     * @return array<string, mixed>|null
     */
    private function resolutionResource(?object $resolution): ?array
    {
        if ($resolution === null) {
            return null;
        }

        return [
            'id' => (string) $resolution->id,
            'reward_result_id' => $resolution->reward_result_id,
            'selected_source_type' => (string) $resolution->selected_source_type,
            'selected_submission_id' => $resolution->selected_submission_id,
            'reason' => $resolution->reason,
            'resolved_by_admin_id' => (string) $resolution->resolved_by_admin_id,
            'resolved_at' => $resolution->resolved_at,
        ];
    }

    /**
     * @return array<string, mixed>|null
     */
    private function scraperSnapshotForResponse(object $session, ?object $submission): ?array
    {
        if ($submission === null || (string) $submission->status !== 'submitted') {
            return null;
        }

        $snapshot = is_array($session->scraper_snapshot_json ?? null) ? $session->scraper_snapshot_json : null;

        if ($snapshot === null) {
            return null;
        }

        return [
            'status' => $snapshot['status'] ?? null,
            'source' => $snapshot['source'] ?? null,
            'live' => $snapshot['live'] ?? null,
            'updated_at' => $snapshot['updated_at'] ?? null,
            'prizes' => $this->normalizePrizeRows($snapshot['prizes'] ?? []),
        ];
    }

    /**
     * @param array<string, mixed> $payload
     */
    private function audit(AdminSessionContext $actor, Request $request, string $action, string $targetType, ?string $targetId, array $payload): void
    {
        $this->auditLogger->logAdminWrite(
            (string) $actor->adminUser['id'],
            'central',
            $action,
            $targetType,
            $targetId,
            $payload,
            null,
            null,
            $request->header('X-Request-Id'),
            $request->ip(),
            $request->userAgent(),
        );
    }

    private function jsonValue(mixed $value): ?string
    {
        return $value === null ? null : json_encode($value, JSON_THROW_ON_ERROR);
    }
}
