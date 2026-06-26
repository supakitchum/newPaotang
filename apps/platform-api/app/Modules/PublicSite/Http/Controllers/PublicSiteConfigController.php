<?php

namespace App\Modules\PublicSite\Http\Controllers;

use App\Modules\Auth\Services\TenantSocialAuthService;
use App\Shared\Auth\ApiErrorResponse;
use App\Modules\Tenancy\Services\TenantConfigurationService;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Routing\Controller;

class PublicSiteConfigController extends Controller
{
    public function __construct(
        private readonly TenantConfigurationService $configuration,
        private readonly TenantSocialAuthService $socialAuth,
    )
    {
    }

    public function show(Request $request): JsonResponse
    {
        $result = $this->configuration->siteConfigForRequest($request);

        if (isset($result['error'])) {
            return ApiErrorResponse::make(
                $request,
                $result['error']['status'],
                $result['error']['code'],
                $result['error']['message'],
            );
        }

        return response()->json(['data' => $result['data']]);
    }

    public function admin(Request $request): JsonResponse
    {
        $result = $this->configuration->adminSiteConfigForRequest($request);

        if (isset($result['error'])) {
            return ApiErrorResponse::make(
                $request,
                $result['error']['status'],
                $result['error']['code'],
                $result['error']['message'],
            );
        }

        return response()->json($result['data']);
    }

    public function mobile(Request $request): JsonResponse
    {
        $result = $this->configuration->siteConfigForRequest($request);

        if (isset($result['error'])) {
            return ApiErrorResponse::make(
                $request,
                $result['error']['status'],
                $result['error']['code'],
                $result['error']['message'],
            );
        }

        $data = $result['data'];
        $tenantId = (string) ($data['tenant_id'] ?? '');
        $line = is_array($data['line'] ?? null) ? $data['line'] : [];
        $realtimeUrl = trim((string) config('platform.realtime.customer_public_url', ''));
        $realtimeKey = trim((string) config('platform.realtime.customer_public_key', 'newpaotang-customer')) ?: 'newpaotang-customer';
        $authProviders = $tenantId !== '' ? $this->socialAuth->enabledProviders($tenantId) : [];
        $enabledAuthProviders = collect($authProviders)
            ->pluck('provider')
            ->map(fn ($provider): string => strtolower((string) $provider))
            ->filter()
            ->values()
            ->all();

        $data['mobile'] = [
            'app_key' => 'customer_flutter',
            'supported_platforms' => ['ios', 'android', 'web'],
            'auth_providers' => $authProviders,
            'line' => [
                'liff_id' => $line['liff_id'] ?? null,
                'liff_enabled' => (bool) ($line['liff_enabled'] ?? false),
                'bot_basic_id' => $line['bot_basic_id'] ?? null,
                'add_friend_url' => $line['add_friend_url'] ?? null,
            ],
            'realtime' => [
                'enabled' => $realtimeUrl !== '',
                'url' => $realtimeUrl,
                'key' => $realtimeKey,
                'auth_endpoint' => '/customer/realtime/auth',
                'protocol' => 7,
                'client' => 'newpaotang-customer',
            ],
            'biometric' => [
                'enabled' => true,
                'requires_pin_setup' => true,
                'assertion_token_ttl_seconds' => 180,
                'platforms' => [
                    'ios' => ['face_id', 'touch_id'],
                    'android' => ['biometric_prompt'],
                    'web' => [],
                ],
            ],
            'screen_security' => [
                'android' => [
                    'flag_secure' => true,
                    'protect_recent_app_preview' => true,
                ],
                'ios' => [
                    'screenshot_policy' => 'lock_and_blank',
                    'screen_capture_overlay' => true,
                    'exit_app' => false,
                ],
                'web' => [
                    'sensitive_screen_mode' => 'limited',
                    'watermark_enabled' => true,
                ],
                'sensitive_routes' => [
                    '/cart',
                    '/checkout',
                    '/success',
                    '/pin',
                    '/tickets',
                    '/tickets/history',
                    '/tickets/view',
                    '/tickets/claim',
                    '/my-wallet',
                    '/topup',
                    '/topup/history',
                    '/reward-claims',
                    '/activity-claims',
                    '/affiliate',
                    '/profile',
                    '/profile/auto-reward',
                    '/profile/biometrics',
                    '/profile/line-notifications',
                    '/profile/reward-bank',
                    '/purchase-history',
                ],
            ],
            'feature_flags' => [
                'native_biometric_unlock' => true,
                'social_login_google' => in_array('google', $enabledAuthProviders, true),
                'social_login_apple' => in_array('apple', $enabledAuthProviders, true),
                'screen_security_native' => true,
            ],
        ];

        return response()->json(['data' => $data]);
    }
}
