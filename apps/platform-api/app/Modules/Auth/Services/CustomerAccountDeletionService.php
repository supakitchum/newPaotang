<?php

namespace App\Modules\Auth\Services;

use App\Models\Customer;
use App\Models\CustomerAccountDeletionRequest;
use App\Models\CustomerAuthSession;
use App\Modules\CustomerNotifications\Services\CustomerNotificationService;
use App\Modules\SmsOtp\Services\SmsOtpService;
use App\Shared\Auth\CustomerSessionContext;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Cache;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Schema;
use Illuminate\Support\Str;

class CustomerAccountDeletionService
{
    private const PIN_CHALLENGE_TTL_SECONDS = 600;
    private const GRACE_PERIOD_HOURS = 168;
    private const PHONE_REUSE_DAYS = 90;
    private const OPEN_STATUSES = ['pending', 'blocked'];
    private const REASON_CODES = ['no_longer_use', 'privacy', 'experience', 'duplicate_account', 'other'];

    public function __construct(
        private readonly CustomerAuthService $customerAuth,
        private readonly SmsOtpService $otp,
        private readonly CustomerNotificationService $notifications,
    ) {
    }

    public function status(CustomerSessionContext $context): array
    {
        $request = $this->openRequest($context->tenantId(), $context->customerId())
            ?? CustomerAccountDeletionRequest::query()
                ->where('tenant_id', $context->tenantId())
                ->where('customer_id', $context->customerId())
                ->latest('created_at')
                ->first();

        return [
            'request' => $request === null ? null : $this->resource($request),
            'eligibility' => $this->eligibility($context->tenantId(), $context->customerId()),
        ];
    }

    public function eligibility(string $tenantId, string $customerId): array
    {
        $blockers = [];

        if (Schema::hasTable('wallets')) {
            $balance = (int) DB::table('wallets')
                ->where('tenant_id', $tenantId)
                ->where('customer_id', $customerId)
                ->sum('balance_amount');
            if ($balance !== 0) {
                $blockers[] = $this->blocker('wallet_balance', 'wallet', ['balance_amount' => $balance]);
            }
        }

        if (Schema::hasTable('orders')) {
            $count = DB::table('orders')
                ->where('tenant_id', $tenantId)
                ->where('customer_id', $customerId)
                ->whereIn('status', ['draft', 'pending_payment', 'processing'])
                ->count();
            if ($count > 0) {
                $blockers[] = $this->blocker('orders_pending', 'purchase_history', ['count' => $count]);
            }
        }

        if (Schema::hasTable('topup_requests')) {
            $count = DB::table('topup_requests')
                ->where('tenant_id', $tenantId)
                ->where('customer_id', $customerId)
                ->whereIn('status', ['pending', 'processing'])
                ->count();
            if ($count > 0) {
                $blockers[] = $this->blocker('topups_pending', 'topup_history', ['count' => $count]);
            }
        }

        $this->appendPendingCount(
            $blockers,
            'reward_claims',
            $tenantId,
            $customerId,
            ['submitted', 'approved', 'processing'],
            'reward_claims_pending',
            'reward_claims',
        );
        $this->appendPendingCount(
            $blockers,
            'activity_claims',
            $tenantId,
            $customerId,
            ['submitted', 'approved', 'processing'],
            'activity_claims_pending',
            'activity_claims',
        );

        if (Schema::hasTable('activity_awards')) {
            $count = DB::table('activity_awards')
                ->where('tenant_id', $tenantId)
                ->where('customer_id', $customerId)
                ->whereIn('status', ['claimable', 'pending'])
                ->count();
            if ($count > 0) {
                $blockers[] = $this->blocker('activity_awards_unclaimed', 'activity_claims', ['count' => $count]);
            }
        }

        if (Schema::hasTable('affiliate_accounts')) {
            $affiliate = DB::table('affiliate_accounts')
                ->where('tenant_id', $tenantId)
                ->where('customer_id', $customerId)
                ->first();
            if ($affiliate !== null && (int) ($affiliate->wallet_balance_amount ?? 0) !== 0) {
                $blockers[] = $this->blocker('affiliate_balance', 'affiliate_withdraw', [
                    'balance_amount' => (int) $affiliate->wallet_balance_amount,
                ]);
            }
            if ($affiliate !== null && Schema::hasTable('affiliate_payouts')) {
                $count = DB::table('affiliate_payouts')
                    ->where('tenant_id', $tenantId)
                    ->where('affiliate_account_id', $affiliate->id)
                    ->whereIn('status', ['pending', 'approved', 'processing'])
                    ->count();
                if ($count > 0) {
                    $blockers[] = $this->blocker('affiliate_payouts_pending', 'affiliate_withdraw', ['count' => $count]);
                }
            }
        }

        return ['eligible' => $blockers === [], 'blockers' => $blockers];
    }

    public function requestOtp(CustomerSessionContext $context, array $payload, Request $request): array
    {
        if ($this->openRequest($context->tenantId(), $context->customerId()) !== null) {
            return ['error' => 'deletion_request_exists'];
        }

        $pin = trim((string) ($payload['pin'] ?? ''));
        $pinResult = $this->customerAuth->verifyPinOrAssertionForContext($context, ['pin' => $pin]);
        if (isset($pinResult['error'])) {
            return $pinResult;
        }

        $token = 'cadp_'.Str::random(72);
        Cache::put($this->pinChallengeKey($token), [
            'tenant_id' => $context->tenantId(),
            'customer_id' => $context->customerId(),
            'session_id' => (string) $context->session['id'],
            'verified_at' => now()->toISOString(),
        ], now()->addSeconds(self::PIN_CHALLENGE_TTL_SECONDS));

        $otpResult = $this->otp->requestOtp(
            $context->tenantId(),
            ['purpose' => SmsOtpService::PURPOSE_ACCOUNT_DELETION],
            $request,
            SmsOtpService::PURPOSE_ACCOUNT_DELETION,
            (string) ($context->customer['phone'] ?? ''),
        );
        if (isset($otpResult['error'])) {
            Cache::forget($this->pinChallengeKey($token));
            return $otpResult;
        }

        return [
            'resource' => [
                ...($otpResult['resource'] ?? []),
                'pin_verification_token' => $token,
            ],
            'status' => 202,
        ];
    }

    public function verifyOtp(CustomerSessionContext $context, array $payload): array
    {
        return $this->otp->verifyOtp(
            $context->tenantId(),
            $payload,
            SmsOtpService::PURPOSE_ACCOUNT_DELETION,
            (string) ($context->customer['phone'] ?? ''),
        );
    }

    public function create(CustomerSessionContext $context, array $payload, Request $httpRequest): array
    {
        $reasonCode = trim((string) ($payload['reason_code'] ?? ''));
        $reasonDetail = trim((string) ($payload['reason_detail'] ?? ''));
        $idempotencyKey = trim((string) $httpRequest->header('Idempotency-Key', ''));
        $errors = [];

        if (! in_array($reasonCode, self::REASON_CODES, true)) {
            $errors['reason_code'][] = 'The reason code is invalid.';
        }
        if (mb_strlen($reasonDetail) > 500) {
            $errors['reason_detail'][] = 'The reason detail may not be greater than 500 characters.';
        }
        if ($reasonCode === 'other' && $reasonDetail === '') {
            $errors['reason_detail'][] = 'The reason detail is required for other.';
        }
        if (mb_strlen($idempotencyKey) < 8 || mb_strlen($idempotencyKey) > 128) {
            $errors['Idempotency-Key'][] = 'The Idempotency-Key header must be between 8 and 128 characters.';
        }
        if ($errors !== []) {
            return ['error' => 'validation_failed', 'errors' => $errors];
        }

        $existingReplay = CustomerAccountDeletionRequest::query()
            ->where('tenant_id', $context->tenantId())
            ->where('customer_id', $context->customerId())
            ->where('idempotency_key', $idempotencyKey)
            ->first();
        if ($existingReplay !== null) {
            return ['resource' => $this->resource($existingReplay), 'status' => 200];
        }
        if ($this->openRequest($context->tenantId(), $context->customerId()) !== null) {
            return ['error' => 'deletion_request_exists'];
        }

        $pinToken = trim((string) ($payload['pin_verification_token'] ?? ''));
        $pinChallenge = Cache::get($this->pinChallengeKey($pinToken));
        if (! is_array($pinChallenge)
            || ($pinChallenge['tenant_id'] ?? null) !== $context->tenantId()
            || ($pinChallenge['customer_id'] ?? null) !== $context->customerId()
            || ($pinChallenge['session_id'] ?? null) !== (string) $context->session['id']) {
            return ['error' => 'pin_verification_invalid'];
        }

        $eligibility = $this->eligibility($context->tenantId(), $context->customerId());
        if (! $eligibility['eligible']) {
            return ['error' => 'deletion_not_eligible', 'details' => $eligibility];
        }

        $consume = $this->otp->consumeVerifiedToken(
            $context->tenantId(),
            (string) ($context->customer['phone'] ?? ''),
            SmsOtpService::PURPOSE_ACCOUNT_DELETION,
            trim((string) ($payload['otp_verification_token'] ?? '')),
        );
        if (($consume['ok'] ?? false) !== true) {
            return ['error' => 'otp_required'];
        }

        $created = DB::transaction(function () use (
            $context,
            $reasonCode,
            $reasonDetail,
            $idempotencyKey,
            $pinChallenge,
        ): CustomerAccountDeletionRequest {
            $now = now();
            $this->releaseReservations($context->tenantId(), $context->customerId(), $now);
            $customer = Customer::query()
                ->where('tenant_id', $context->tenantId())
                ->whereKey($context->customerId())
                ->lockForUpdate()
                ->firstOrFail();

            return CustomerAccountDeletionRequest::query()->create([
                'id' => 'cad_'.Str::ulid()->toBase32(),
                'tenant_id' => $context->tenantId(),
                'customer_id' => $context->customerId(),
                'status' => 'pending',
                'reason_code' => $reasonCode,
                'reason_detail' => $reasonDetail !== '' ? $reasonDetail : null,
                'idempotency_key' => $idempotencyKey,
                'payload_hash' => hash('sha256', json_encode([$reasonCode, $reasonDetail], JSON_UNESCAPED_UNICODE)),
                'pin_verified_at' => $pinChallenge['verified_at'],
                'otp_verified_at' => $now,
                'requested_at' => $now,
                'scheduled_for' => $now->copy()->addHours(self::GRACE_PERIOD_HOURS),
                'identity_snapshot_json' => [
                    'phone' => $customer->phone,
                    'email' => $customer->email,
                    'name' => $customer->name,
                    'customer_no' => $customer->customer_no,
                ],
            ]);
        });

        Cache::forget($this->pinChallengeKey($pinToken));
        $this->notify($created, 'account.deletion.requested');

        return ['resource' => $this->resource($created), 'status' => 201];
    }

    public function cancel(CustomerSessionContext $context, array $payload): array
    {
        $pinResult = $this->customerAuth->verifyPinOrAssertionForContext(
            $context,
            ['pin' => trim((string) ($payload['pin'] ?? ''))],
        );
        if (isset($pinResult['error'])) {
            return $pinResult;
        }

        $request = DB::transaction(function () use ($context): ?CustomerAccountDeletionRequest {
            $request = CustomerAccountDeletionRequest::query()
                ->where('tenant_id', $context->tenantId())
                ->where('customer_id', $context->customerId())
                ->whereIn('status', self::OPEN_STATUSES)
                ->lockForUpdate()
                ->first();
            if ($request === null) {
                return null;
            }
            $request->forceFill([
                'status' => 'cancelled',
                'cancelled_at' => now(),
                'updated_at' => now(),
            ])->save();
            return $request->fresh();
        });

        if ($request === null) {
            return ['error' => 'deletion_request_not_found'];
        }
        $this->notify($request, 'account.deletion.cancelled');

        return ['resource' => $this->resource($request)];
    }

    public function processDue(int $limit = 100): array
    {
        $selected = CustomerAccountDeletionRequest::query()
            ->whereIn('status', self::OPEN_STATUSES)
            ->where('scheduled_for', '<=', now())
            ->orderBy('scheduled_for')
            ->limit(max(1, min($limit, 500)))
            ->pluck('id');
        $completed = 0;
        $blocked = 0;

        foreach ($selected as $id) {
            $result = $this->finalize((string) $id);
            $completed += $result === 'completed' ? 1 : 0;
            $blocked += $result === 'blocked' ? 1 : 0;
        }

        return ['selected' => $selected->count(), 'completed' => $completed, 'blocked' => $blocked];
    }

    public function sendDueReminders(int $limit = 100): int
    {
        $requests = CustomerAccountDeletionRequest::query()
            ->where('status', 'pending')
            ->whereNull('reminder_sent_at')
            ->whereBetween('scheduled_for', [now(), now()->addDay()])
            ->limit(max(1, min($limit, 500)))
            ->get();
        foreach ($requests as $request) {
            $this->notify($request, 'account.deletion.reminder');
            $request->forceFill(['reminder_sent_at' => now(), 'updated_at' => now()])->save();
        }
        return $requests->count();
    }

    private function finalize(string $requestId): string
    {
        $notification = null;
        $result = DB::transaction(function () use ($requestId, &$notification): string {
            $request = CustomerAccountDeletionRequest::query()->whereKey($requestId)->lockForUpdate()->first();
            if ($request === null || ! in_array($request->status, self::OPEN_STATUSES, true)) {
                return 'skipped';
            }
            $eligibility = $this->eligibility((string) $request->tenant_id, (string) $request->customer_id);
            if (! $eligibility['eligible']) {
                $request->forceFill([
                    'status' => 'blocked',
                    'blockers_json' => $eligibility['blockers'],
                    'blocked_at' => $request->blocked_at ?? now(),
                    'last_checked_at' => now(),
                    'updated_at' => now(),
                ])->save();
                $notification = $request->fresh();
                return 'blocked';
            }

            $now = now();
            Customer::query()
                ->where('tenant_id', $request->tenant_id)
                ->whereKey($request->customer_id)
                ->update([
                    'status' => 'deleted',
                    'deleted_at' => $now,
                    'phone_reuse_after' => $now->copy()->addDays(self::PHONE_REUSE_DAYS),
                    'password_hash' => null,
                    'pin_hash' => null,
                    'updated_at' => $now,
                ]);
            CustomerAuthSession::query()
                ->where('tenant_id', $request->tenant_id)
                ->where('customer_id', $request->customer_id)
                ->whereNull('revoked_at')
                ->update(['revoked_at' => $now, 'revoked_reason' => 'account_deleted', 'updated_at' => $now]);
            $this->revokeCredentials((string) $request->tenant_id, (string) $request->customer_id, $now);
            $request->forceFill([
                'status' => 'completed',
                'completed_at' => $now,
                'last_checked_at' => $now,
                'blockers_json' => null,
                'updated_at' => $now,
            ])->save();
            $notification = $request->fresh();
            return 'completed';
        });

        if ($notification instanceof CustomerAccountDeletionRequest) {
            $this->notify(
                $notification,
                $result === 'completed' ? 'account.deletion.completed' : 'account.deletion.blocked',
            );
        }
        return $result;
    }

    private function revokeCredentials(string $tenantId, string $customerId, mixed $now): void
    {
        $updates = [
            'customer_push_devices' => ['revoked_at' => $now, 'updated_at' => $now],
            'customer_biometric_devices' => ['status' => 'revoked', 'revoked_at' => $now, 'updated_at' => $now],
            'customer_passkeys' => ['status' => 'revoked', 'revoked_at' => $now, 'updated_at' => $now],
            'customer_social_identities' => ['revoked_at' => $now, 'updated_at' => $now],
            'customer_line_identities' => ['revoked_at' => $now, 'notification_enabled' => false, 'updated_at' => $now],
        ];
        foreach ($updates as $table => $values) {
            if (! Schema::hasTable($table)) {
                continue;
            }
            $customerColumn = $table === 'customer_passkeys' ? 'user_id' : 'customer_id';
            DB::table($table)
                ->where('tenant_id', $tenantId)
                ->where($customerColumn, $customerId)
                ->update($values);
        }
    }

    private function releaseReservations(string $tenantId, string $customerId, mixed $now): void
    {
        if (! Schema::hasTable('stock_reservations')) {
            return;
        }
        $ids = DB::table('stock_reservations')
            ->where('tenant_id', $tenantId)
            ->where('customer_id', $customerId)
            ->where('status', 'active')
            ->pluck('id');
        if ($ids->isEmpty()) {
            return;
        }
        DB::table('stock_reservations')->whereIn('id', $ids)->update([
            'status' => 'released',
            'released_at' => $now,
            'updated_at' => $now,
        ]);
        if (Schema::hasTable('stock_reservation_items')) {
            DB::table('stock_reservation_items')->whereIn('reservation_id', $ids)->update([
                'status' => 'released',
                'updated_at' => $now,
            ]);
        }
    }

    private function notify(CustomerAccountDeletionRequest $request, string $event): void
    {
        $content = match ($event) {
            'account.deletion.requested' => [
                'title' => ['th-TH' => 'รับคำขอลบบัญชีแล้ว', 'en-US' => 'Account deletion scheduled'],
                'body' => ['th-TH' => 'บัญชีจะถูกปิดใน 7 วัน คุณสามารถยกเลิกคำขอได้ก่อนครบกำหนด', 'en-US' => 'Your account will close in 7 days. You can cancel before the deadline.'],
            ],
            'account.deletion.reminder' => [
                'title' => ['th-TH' => 'บัญชีจะถูกปิดภายใน 24 ชั่วโมง', 'en-US' => 'Account closes within 24 hours'],
                'body' => ['th-TH' => 'ยกเลิกคำขอได้จากหน้าลบบัญชีก่อนครบกำหนด', 'en-US' => 'Cancel from the account deletion page before the deadline.'],
            ],
            'account.deletion.blocked' => [
                'title' => ['th-TH' => 'ยังปิดบัญชีไม่ได้', 'en-US' => 'Account closure is blocked'],
                'body' => ['th-TH' => 'ยังมีรายการหรือยอดคงค้าง กรุณาตรวจสอบในแอป', 'en-US' => 'An outstanding balance or transaction must be resolved.'],
            ],
            'account.deletion.cancelled' => [
                'title' => ['th-TH' => 'ยกเลิกคำขอลบบัญชีแล้ว', 'en-US' => 'Account deletion cancelled'],
                'body' => ['th-TH' => 'บัญชีของคุณกลับมาใช้งานได้ตามปกติ', 'en-US' => 'Your account is available normally again.'],
            ],
            default => [
                'title' => ['th-TH' => 'ปิดบัญชีเรียบร้อยแล้ว', 'en-US' => 'Account closed'],
                'body' => ['th-TH' => 'ข้อมูลธุรกรรมถูกเก็บไว้เป็นหลักฐานตามข้อกำหนด', 'en-US' => 'Transaction records remain retained as required.'],
            ],
        };
        $this->notifications->createForCustomer(
            (string) $request->tenant_id,
            (string) $request->customer_id,
            $event,
            [
                'category' => 'account',
                ...$content,
                'icon_key' => 'security',
                'action_key' => 'route',
                'action_entity_id' => '/profile/account-deletion',
                'subject_type' => 'customer_account_deletion_request',
                'subject_id' => (string) $request->id,
            ],
            [
                'dedupe_key' => $event.':'.$request->id,
                'allow_inactive_customer' => true,
            ],
        );
    }

    private function resource(CustomerAccountDeletionRequest $request): array
    {
        $remaining = $request->scheduled_for === null
            ? 0
            : max(0, now()->diffInSeconds($request->scheduled_for, false));

        return [
            'id' => (string) $request->id,
            'status' => (string) $request->status,
            'reason_code' => (string) $request->reason_code,
            'reason_detail' => $request->reason_detail,
            'requested_at' => $request->requested_at?->toISOString(),
            'scheduled_for' => $request->scheduled_for?->toISOString(),
            'remaining_seconds' => $remaining,
            'blockers' => $request->blockers_json ?? [],
            'cancelled_at' => $request->cancelled_at?->toISOString(),
            'completed_at' => $request->completed_at?->toISOString(),
            'phone_reuse_after' => $request->completed_at?->copy()->addDays(self::PHONE_REUSE_DAYS)->toISOString(),
            'read_only' => in_array((string) $request->status, self::OPEN_STATUSES, true),
        ];
    }

    private function openRequest(string $tenantId, string $customerId): ?CustomerAccountDeletionRequest
    {
        return CustomerAccountDeletionRequest::query()
            ->where('tenant_id', $tenantId)
            ->where('customer_id', $customerId)
            ->whereIn('status', self::OPEN_STATUSES)
            ->first();
    }

    private function pinChallengeKey(string $token): string
    {
        return 'customer-account-deletion-pin:'.hash('sha256', $token);
    }

    private function blocker(string $code, string $route, array $details): array
    {
        return ['code' => $code, 'route_key' => $route, 'details' => $details];
    }

    private function appendPendingCount(
        array &$blockers,
        string $table,
        string $tenantId,
        string $customerId,
        array $statuses,
        string $code,
        string $route,
    ): void {
        if (! Schema::hasTable($table)) {
            return;
        }
        $count = DB::table($table)
            ->where('tenant_id', $tenantId)
            ->where('customer_id', $customerId)
            ->whereIn('status', $statuses)
            ->count();
        if ($count > 0) {
            $blockers[] = $this->blocker($code, $route, ['count' => $count]);
        }
    }
}
