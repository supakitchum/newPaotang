<?php

namespace App\Modules\PublicSite\Http\Controllers;

use App\Modules\Auth\Passkeys\CustomerPasskeyConfiguration;
use App\Modules\Auth\Services\TenantSocialAuthService;
use App\Shared\Auth\ApiErrorResponse;
use App\Modules\Tenancy\Services\TenantConfigurationService;
use App\Support\RealtimeUrl;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Routing\Controller;

class PublicSiteConfigController extends Controller
{
    public function __construct(
        private readonly TenantConfigurationService $configuration,
        private readonly TenantSocialAuthService $socialAuth,
        private readonly CustomerPasskeyConfiguration $passkeys,
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
        $site = is_array($data['site'] ?? null) ? $data['site'] : [];
        $line = is_array($data['line'] ?? null) ? $data['line'] : [];
        $features = is_array($data['features'] ?? null) ? $data['features'] : [];
        $api = is_array($data['api'] ?? null) ? $data['api'] : [];
        $realtimeUrl = RealtimeUrl::resolve(
            $api['realtime_url'] ?? null,
            config('platform.realtime.customer_public_url'),
        );
        $realtimeKey = trim((string) config('broadcasting.connections.reverb.key', ''));
        $realtimeClient = trim((string) config('platform.realtime.customer_client', 'customer-flutter')) ?: 'customer-flutter';
        $realtimeAuthEndpoint = trim((string) config('platform.realtime.customer_auth_endpoint', '/customer/realtime/auth')) ?: '/customer/realtime/auth';
        $realtimeProtocol = max(1, (int) config('platform.realtime.customer_protocol', 7));
        $authProviders = $tenantId !== '' ? $this->socialAuth->enabledProviders($tenantId) : [];
        $nativeLineLogin = $tenantId !== ''
            ? $this->socialAuth->lineNativeLoginConfig($tenantId)
            : ['enabled' => false, 'channel_id' => null];
        $enabledAuthProviders = collect($authProviders)
            ->pluck('provider')
            ->map(fn ($provider): string => strtolower((string) $provider))
            ->filter()
            ->values()
            ->all();
        $domain = is_array($data['domain'] ?? null) ? $data['domain'] : [];
        $passkeys = $this->passkeys->resolve([
            'tenant_id' => $tenantId,
            'host' => $domain['host'] ?? $request->getHost(),
        ]);

        $data['mobile'] = [
            'app_key' => 'customer_flutter',
            'supported_platforms' => ['ios', 'android', 'web'],
            'lottery_product_label' => $site['lottery_product_label'] ?? null,
            'ticket_image_watermark' => $site['ticket_image_watermark'] ?? null,
            'auth_providers' => $authProviders,
            'line' => [
                'liff_id' => $line['liff_id'] ?? null,
                'liff_enabled' => (bool) ($line['liff_enabled'] ?? false),
                'bot_basic_id' => $line['bot_basic_id'] ?? null,
                'add_friend_url' => $line['add_friend_url'] ?? null,
                'native_login_enabled' => (bool) ($nativeLineLogin['enabled'] ?? false),
                'native_channel_id' => $nativeLineLogin['channel_id'] ?? null,
            ],
            'realtime' => [
                'enabled' => $realtimeUrl !== '' && $realtimeKey !== '',
                'url' => $realtimeUrl,
                'key' => $realtimeKey,
                'auth_endpoint' => $realtimeAuthEndpoint,
                'protocol' => $realtimeProtocol,
                'client' => $realtimeClient,
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
            'passkeys' => [
                'enabled' => $passkeys['enabled'],
                'rp_id' => $passkeys['rp_id'],
                'rp_name' => $passkeys['rp_name'],
                'timeout_ms' => $passkeys['timeout'],
                'max_passkeys' => $passkeys['max_per_customer'],
                'platforms' => ['ios', 'android', 'web'],
            ],
            'screen_security' => [
                'android' => [
                    'flag_secure' => true,
                    'protect_recent_app_preview' => true,
                ],
                'ios' => [
                    'screenshot_policy' => 'lock_and_blank',
                    'screen_capture_overlay' => true,
                    'exit_app' => true,
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
                    '/profile/account-deletion',
                    '/profile/biometrics',
                    '/profile/passkeys',
                    '/profile/social-accounts',
                    '/profile/line-notifications',
                    '/profile/reward-bank',
                    '/purchase-history',
                ],
            ],
            'feature_flags' => array_replace(
                $features,
                [
                    'native_biometric_unlock' => (bool) ($features['native_biometric_unlock'] ?? true),
                    'social_login_google' => in_array('google', $enabledAuthProviders, true),
                    'social_login_apple' => in_array('apple', $enabledAuthProviders, true),
                    'social_login_facebook' => in_array('facebook', $enabledAuthProviders, true),
                    'social_login_line_native' => (bool) ($nativeLineLogin['enabled'] ?? false),
                    'passkey_login' => $passkeys['enabled'],
                    'screen_security_native' => (bool) ($features['screen_security_native'] ?? true),
                ],
            ),
        ];

        return response()->json(['data' => $data]);
    }
}
