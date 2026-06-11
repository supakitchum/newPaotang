<?php

namespace App\Shared\Localization\Http\Middleware;

use App\Models\AdminAuthSession;
use App\Models\CustomerAuthSession;
use App\Models\PartnerTenantDomain;
use App\Shared\Tenancy\TenantHostNormalizer;
use Closure;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Schema;
use Symfony\Component\HttpFoundation\Response;

class SetApiLocale
{
    public const DEFAULT_CUSTOMER_LOCALE = 'th-TH';
    public const DEFAULT_ADMIN_LOCALE = 'en-US';

    private const SUPPORTED = ['th-TH', 'en-US'];

    /**
     * @param Closure(Request): Response $next
     */
    public function handle(Request $request, Closure $next): Response
    {
        $locale = $this->resolveLocale($request);

        app()->setLocale($locale);
        $request->attributes->set('api_locale', $locale);

        $response = $next($request);
        $response->headers->set('Content-Language', $locale);
        $this->appendVary($response, 'Accept-Language');

        return $response;
    }

    private function resolveLocale(Request $request): string
    {
        return $this->authenticatedPreferredLocale($request)
            ?? $this->canonicalLocale($request->header('X-Locale'))
            ?? $this->acceptLanguageLocale($request)
            ?? $this->tenantDefaultLocale($request)
            ?? $this->routeDefaultLocale($request);
    }

    private function authenticatedPreferredLocale(Request $request): ?string
    {
        $token = $request->bearerToken();

        if ($token === null || $token === '') {
            return null;
        }

        $hash = hash('sha256', $token);

        try {
            if (Schema::hasTable('customer_auth_sessions') && Schema::hasColumn('customers', 'preferred_locale')) {
                $customerLocale = CustomerAuthSession::query()
                    ->join('customers', 'customers.id', '=', 'customer_auth_sessions.customer_id')
                    ->where('customer_auth_sessions.access_token_hash', $hash)
                    ->whereNull('customer_auth_sessions.revoked_at')
                    ->where('customer_auth_sessions.access_expires_at', '>', now())
                    ->value('customers.preferred_locale');

                $locale = $this->canonicalLocale($customerLocale);

                if ($locale !== null) {
                    return $locale;
                }
            }

            if (Schema::hasTable('admin_auth_sessions') && Schema::hasColumn('admin_users', 'preferred_locale')) {
                $adminLocale = AdminAuthSession::query()
                    ->join('admin_users', 'admin_users.id', '=', 'admin_auth_sessions.admin_user_id')
                    ->where('admin_auth_sessions.access_token_hash', $hash)
                    ->whereNull('admin_auth_sessions.revoked_at')
                    ->where('admin_auth_sessions.access_expires_at', '>', now())
                    ->value('admin_users.preferred_locale');

                return $this->canonicalLocale($adminLocale);
            }
        } catch (\Throwable) {
            return null;
        }

        return null;
    }

    private function acceptLanguageLocale(Request $request): ?string
    {
        $header = trim((string) $request->header('Accept-Language', ''));

        if ($header === '') {
            return null;
        }

        $candidates = [];
        foreach (explode(',', $header) as $part) {
            [$tag, $qPart] = array_pad(explode(';q=', trim($part), 2), 2, '1');
            $quality = is_numeric($qPart) ? (float) $qPart : 1.0;
            $candidates[] = ['tag' => $tag, 'quality' => $quality];
        }

        usort($candidates, fn (array $a, array $b): int => $b['quality'] <=> $a['quality']);

        foreach ($candidates as $candidate) {
            $locale = $this->canonicalLocale($candidate['tag']);

            if ($locale !== null) {
                return $locale;
            }
        }

        return null;
    }

    private function tenantDefaultLocale(Request $request): ?string
    {
        try {
            if (! Schema::hasTable('partner_tenant_domains') || ! Schema::hasTable('partner_tenant_settings')) {
                return null;
            }

            $host = $this->normalizeHost((string) ($request->headers->get('Host') ?: $request->getHost()));

            if ($host === '') {
                return null;
            }

            $locale = PartnerTenantDomain::query()
                ->leftJoin('partner_tenant_settings', 'partner_tenant_settings.tenant_id', '=', 'partner_tenant_domains.tenant_id')
                ->whereIn('partner_tenant_domains.host', TenantHostNormalizer::variants($host))
                ->value('partner_tenant_settings.locale');

            return $this->canonicalLocale($locale);
        } catch (\Throwable) {
            return null;
        }
    }

    private function routeDefaultLocale(Request $request): string
    {
        return $request->is('api/v1/admin/*') || $request->is('api/v1/auth/admin/*')
            ? self::DEFAULT_ADMIN_LOCALE
            : self::DEFAULT_CUSTOMER_LOCALE;
    }

    private function canonicalLocale(mixed $value): ?string
    {
        $locale = str_replace('_', '-', strtolower(trim((string) $value)));

        return match ($locale) {
            'th', 'th-th' => 'th-TH',
            'en', 'en-us', 'en-gb' => 'en-US',
            default => null,
        };
    }

    private function normalizeHost(string $host): string
    {
        return strtolower(trim(preg_replace('/:\d+$/', '', $host) ?? ''));
    }

    private function appendVary(Response $response, string $header): void
    {
        $existing = array_filter(array_map('trim', explode(',', (string) $response->headers->get('Vary', ''))));

        if (! in_array($header, $existing, true)) {
            $existing[] = $header;
        }

        $response->headers->set('Vary', implode(', ', $existing));
    }
}
