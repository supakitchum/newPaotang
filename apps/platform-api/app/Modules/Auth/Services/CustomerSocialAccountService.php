<?php

namespace App\Modules\Auth\Services;

use App\Models\CustomerLineIdentity;
use App\Models\CustomerSocialIdentity;
use App\Shared\Auth\CustomerSessionContext;
use Illuminate\Support\Facades\DB;

class CustomerSocialAccountService
{
    private const PROVIDERS = ['line', 'google', 'apple', 'facebook'];

    /**
     * @return array<string, mixed>
     */
    public function accounts(CustomerSessionContext $context): array
    {
        $generic = CustomerSocialIdentity::query()
            ->where('tenant_id', $context->tenantId())
            ->where('customer_id', $context->customerId())
            ->whereNull('revoked_at')
            ->get()
            ->keyBy(fn (CustomerSocialIdentity $identity): string => (string) $identity->provider);
        $line = CustomerLineIdentity::query()
            ->where('tenant_id', $context->tenantId())
            ->where('customer_id', $context->customerId())
            ->whereNull('revoked_at')
            ->first();

        return [
            'accounts' => array_map(function (string $provider) use ($generic, $line): array {
                if ($provider === 'line') {
                    return [
                        'provider' => $provider,
                        'linked' => $line instanceof CustomerLineIdentity,
                        'display_name' => $line?->display_name,
                        'email' => null,
                        'picture_url' => $line?->picture_url,
                        'linked_at' => $line?->linked_at?->toISOString(),
                        'last_login_at' => $line?->last_login_at?->toISOString(),
                    ];
                }

                $identity = $generic->get($provider);

                return [
                    'provider' => $provider,
                    'linked' => $identity instanceof CustomerSocialIdentity,
                    'display_name' => $identity?->display_name,
                    'email' => $identity?->email,
                    'picture_url' => $identity?->avatar_url,
                    'linked_at' => $identity?->linked_at?->toISOString(),
                    'last_login_at' => $identity?->last_login_at?->toISOString(),
                ];
            }, self::PROVIDERS),
        ];
    }

    /**
     * @return array{resource?: array<string, mixed>, error?: string}
     */
    public function unlink(CustomerSessionContext $context, string $provider): array
    {
        $provider = $this->normalizeProvider($provider);
        if (! in_array($provider, self::PROVIDERS, true)) {
            return ['error' => 'provider_not_supported'];
        }

        return DB::transaction(function () use ($context, $provider): array {
            $query = $provider === 'line'
                ? CustomerLineIdentity::query()
                    ->where('tenant_id', $context->tenantId())
                    ->where('customer_id', $context->customerId())
                : CustomerSocialIdentity::query()
                    ->where('tenant_id', $context->tenantId())
                    ->where('customer_id', $context->customerId())
                    ->where('provider', $provider);

            $identity = $query->lockForUpdate()->first();
            if ($identity === null) {
                return ['resource' => $this->accounts($context)];
            }

            $identity->delete();

            return ['resource' => $this->accounts($context)];
        });
    }

    private function normalizeProvider(string $provider): string
    {
        return match (strtolower(trim($provider))) {
            'gmail', 'google_login', 'google_oauth', 'google_oauth2' => 'google',
            'apple_id', 'apple_login', 'sign_in_with_apple' => 'apple',
            'fb', 'facebook_login', 'facebook_oauth', 'meta', 'meta_login' => 'facebook',
            'line_login', 'line_oauth' => 'line',
            default => strtolower(trim($provider)),
        };
    }
}
