<?php

namespace App\Modules\SmsOtp\Contracts;

use App\Models\TenantSmsProvider;

interface SmsOtpProviderInterface
{
    /**
     * @return array{ok: bool, status?: int|null, provider_message_id?: string|null, provider_token?: string|null, provider_refno?: string|null, message?: string|null, response?: array<string, mixed>|null, latency_ms?: int|null}
     */
    public function requestOtp(TenantSmsProvider $provider, string $phone): array;

    /**
     * @return array{ok: bool, status?: int|null, message?: string|null, response?: array<string, mixed>|null, latency_ms?: int|null}
     */
    public function verifyOtp(TenantSmsProvider $provider, string $providerToken, string $pin): array;
}
