<?php

namespace App\Modules\SmsOtp\Contracts;

use App\Models\TenantSmsProvider;

interface SmsOtpProviderInterface
{
    /**
     * @return array{ok: bool, status?: int|null, provider_message_id?: string|null, message?: string|null, response?: array<string, mixed>|null, latency_ms?: int|null}
     */
    public function send(TenantSmsProvider $provider, string $phone, string $message): array;
}
