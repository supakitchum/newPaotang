<?php

namespace App\Modules\Commerce\Services;

use App\Models\TenantPaymentProviderConnection;
use App\Modules\Commerce\Services\PaymentProviders\DeepayKbankPaymentProvider;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Crypt;

class PaymentWebhookAuthenticator
{
    public function verify(string $provider, ?object $payment, ?object $topup, Request $request): bool
    {
        $tenantId = trim((string) ($payment->tenant_id ?? $topup->tenant_id ?? ''));
        if ($tenantId === '' || ($payment !== null && (string) $payment->provider !== $provider)) {
            return false;
        }
        if (
            $payment !== null
            && $topup !== null
            && (string) $payment->tenant_id !== (string) $topup->tenant_id
        ) {
            return false;
        }

        $connection = TenantPaymentProviderConnection::query()
            ->forTenant($tenantId)
            ->where('provider', $provider)
            ->where('status', 'active')
            ->whereNotNull('api_key_encrypted')
            ->first();
        if ($connection === null) {
            return false;
        }

        if ($provider === DeepayKbankPaymentProvider::PROVIDER) {
            return $this->verifyTrustedDeepayCallback($payment, $topup, $request);
        }

        $secret = $this->decryptSecret($connection->webhook_secret_encrypted);
        if ($secret === '') {
            return false;
        }

        $metadata = is_array($connection->metadata_json) ? $connection->metadata_json : [];
        $mode = strtolower(trim((string) ($metadata['webhook_auth_mode'] ?? 'hmac_sha256')));

        return match ($mode) {
            'token' => $this->verifyToken($secret, $request),
            'hmac_sha256' => $this->verifyHmac($secret, $request),
            default => false,
        };
    }

    private function verifyTrustedDeepayCallback(?object $payment, ?object $topup, Request $request): bool
    {
        if ($payment === null || $topup === null) {
            return false;
        }

        $payload = $request->all();
        $providerReference = trim((string) (
            $payload['partnerTxnUid']
            ?? data_get($payload, 'payload.partnerTxnUid', '')
        ));
        $reference1 = trim((string) (
            $payload['reference1']
            ?? data_get($payload, 'payload.reference1', '')
        ));
        $reference2 = strtolower(trim((string) (
            $payload['reference2']
            ?? data_get($payload, 'payload.reference2', '')
        )));
        $reference3 = trim((string) (
            $payload['reference3']
            ?? data_get($payload, 'payload.reference3', '')
        ));

        if (
            $providerReference === ''
            || $reference1 === ''
            || $reference2 !== 'wallet'
            || ! hash_equals((string) $payment->provider_reference, $providerReference)
            || ! hash_equals((string) $topup->id, $reference1)
        ) {
            return false;
        }

        $tenantId = (string) $payment->tenant_id;

        return (string) $payment->provider === DeepayKbankPaymentProvider::PROVIDER
            && (string) $payment->topup_request_id === (string) $topup->id
            && (string) $topup->payment_id === (string) $payment->id
            && (string) $topup->tenant_id === $tenantId
            && ($reference3 === '' || hash_equals($tenantId, $reference3));
    }

    private function verifyToken(string $secret, Request $request): bool
    {
        $token = trim((string) $request->header('X-Webhook-Token', ''));
        if ($token === '') {
            $authorization = trim((string) $request->header('Authorization', ''));
            $token = preg_match('/\ABearer\s+(.+)\z/i', $authorization, $matches) === 1
                ? trim((string) $matches[1])
                : '';
        }

        return $token !== '' && hash_equals($secret, $token);
    }

    private function verifyHmac(string $secret, Request $request): bool
    {
        $timestamp = trim((string) $request->header('X-Webhook-Timestamp', ''));
        if (preg_match('/\A\d{10}\z/', $timestamp) !== 1) {
            return false;
        }

        $tolerance = max(30, (int) config('services.payment_webhooks.timestamp_tolerance_seconds', 300));
        if (abs(now()->timestamp - (int) $timestamp) > $tolerance) {
            return false;
        }

        $signature = trim((string) (
            $request->header('X-Signature')
            ?? $request->header('X-Webhook-Signature')
            ?? ''
        ));
        if (str_starts_with(strtolower($signature), 'sha256=')) {
            $signature = substr($signature, 7);
        }
        if (preg_match('/\A[a-f0-9]{64}\z/i', $signature) !== 1) {
            return false;
        }

        $expected = hash_hmac('sha256', $timestamp.'.'.$request->getContent(), $secret);

        return hash_equals($expected, strtolower($signature));
    }

    private function decryptSecret(mixed $encrypted): string
    {
        $encrypted = trim((string) $encrypted);
        if ($encrypted === '') {
            return '';
        }

        try {
            return trim(Crypt::decryptString($encrypted));
        } catch (\Throwable) {
            return '';
        }
    }
}
