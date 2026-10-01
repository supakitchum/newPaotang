<?php

namespace App\Modules\PublicSite\Http\Controllers;

use App\Modules\PartnerStore\Services\PartnerStoreService;
use App\Shared\Auth\ApiErrorResponse;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Routing\Controller;
use Illuminate\Support\Carbon;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Schema;
use Illuminate\Support\Str;

class PublicVisitController extends Controller
{
    public function __construct(private readonly PartnerStoreService $partnerStore)
    {
    }

    public function track(Request $request): JsonResponse
    {
        $tenant = $this->tenantContext($request);

        if ($tenant instanceof JsonResponse) {
            return $tenant;
        }

        if (! Schema::hasTable('public_visit_sessions')) {
            return response()->json([
                'data' => [
                    'ok' => true,
                    'tracked' => false,
                    'reason' => 'tracking_table_missing',
                ],
            ]);
        }

        $visitorKey = $this->cleanKey($request->input('visitor_id'), 128);
        $sessionKey = $this->cleanKey($request->input('session_id'), 128);

        if ($visitorKey === '' || $sessionKey === '') {
            return ApiErrorResponse::validationFailed($request, [
                'visitor_id' => ['The visitor_id field is required.'],
                'session_id' => ['The session_id field is required.'],
            ]);
        }

        $now = now();
        $customerId = $this->customerIdFromBearer((string) $tenant['tenant_id'], $request->bearerToken());
        $existing = DB::table('public_visit_sessions')
            ->where('tenant_id', $tenant['tenant_id'])
            ->where('session_key', $sessionKey)
            ->first(['id', 'first_seen_at']);
        $id = $existing?->id ?? 'pvs_'.Str::ulid()->toBase32();
        $firstSeenAt = $existing?->first_seen_at ?? $now;
        $source = $this->cleanEnum($request->input('source'), 'direct', 64);
        $channel = $this->cleanNullable($request->input('channel'), 96);
        $path = $this->cleanNullable($request->input('path'), 255);
        $referrer = $this->cleanNullable($request->input('referrer'), 2000);
        $screen = $this->cleanNullable($request->input('screen'), 40);
        $timezone = $this->cleanNullable($request->input('timezone'), 80);

        DB::table('public_visit_sessions')->updateOrInsert([
            'tenant_id' => (string) $tenant['tenant_id'],
            'session_key' => $sessionKey,
        ], [
            'id' => $id,
            'partner_id' => (string) $tenant['partner_id'],
            'customer_id' => $customerId,
            'visitor_key' => $visitorKey,
            'source' => $source,
            'channel' => $channel,
            'path' => $path,
            'referrer' => $referrer,
            'ip_address' => $request->ip(),
            'user_agent' => $this->cleanNullable($request->userAgent(), 1000),
            'screen' => $screen,
            'timezone' => $timezone,
            'first_seen_at' => $firstSeenAt,
            'last_seen_at' => $now,
            'expires_at' => $now->copy()->addMinutes(20),
            'metadata_json' => json_encode([
                'authenticated' => $customerId !== null,
                'route_name' => $this->cleanNullable($request->input('route_name'), 120),
            ], JSON_THROW_ON_ERROR),
            'created_at' => $existing?->first_seen_at === null ? $now : ($existing?->first_seen_at ?? $now),
            'updated_at' => $now,
        ]);

        return response()->json([
            'data' => [
                'ok' => true,
                'tracked' => true,
                'visitor_id' => $visitorKey,
                'session_id' => $sessionKey,
                'expires_at' => Carbon::parse($now)->addMinutes(20)->toISOString(),
            ],
        ]);
    }

    /**
     * @return array<string, mixed>|JsonResponse
     */
    private function tenantContext(Request $request): array|JsonResponse
    {
        $result = $this->partnerStore->tenantContextForRequest($request, false);

        if (isset($result['error'])) {
            return ApiErrorResponse::make(
                $request,
                $result['error']['status'],
                $result['error']['code'],
                $result['error']['message'],
            );
        }

        return $result['context'];
    }

    private function customerIdFromBearer(string $tenantId, ?string $token): ?string
    {
        if ($token === null || $token === '' || ! Schema::hasTable('customer_auth_sessions')) {
            return null;
        }

        $session = DB::table('customer_auth_sessions')
            ->where('tenant_id', $tenantId)
            ->where('access_token_hash', hash('sha256', $token))
            ->whereNull('revoked_at')
            ->where('access_expires_at', '>=', now())
            ->first(['customer_id']);

        return $session === null ? null : (string) $session->customer_id;
    }

    private function cleanKey(mixed $value, int $max): string
    {
        $clean = preg_replace('/[^A-Za-z0-9:_\\-.]/', '', trim((string) $value)) ?? '';

        return substr($clean, 0, $max);
    }

    private function cleanEnum(mixed $value, string $fallback, int $max): string
    {
        $clean = strtolower($this->cleanKey($value, $max));

        return $clean === '' ? $fallback : $clean;
    }

    private function cleanNullable(mixed $value, int $max): ?string
    {
        $clean = trim((string) $value);

        if ($clean === '') {
            return null;
        }

        return mb_substr($clean, 0, $max);
    }
}
