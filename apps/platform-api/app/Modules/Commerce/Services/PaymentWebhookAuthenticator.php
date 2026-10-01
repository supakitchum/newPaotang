<?php

namespace App\Modules\Commerce\Services;

use App\Models\TenantPaymentProviderConnection;
use App\Models\PaymentProviderAttempt;
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

        $secret = $this->decryptSecret($connection->webhook_secret_encrypted);
        $metadata = is_array($connection->metadata_json) ? $connection->metadata_json : [];
        $mode = strtolower(trim((string) ($metadata['webhook_auth_mode'] ?? 'hmac_sha256')));

        if ($provider === DeepayKbankPaymentProvider::PROVIDER && $mode === 'trusted_provider') {
            return $this->verifyTrustedDeepayCallback($payment, $topup, $request);
        }

        if ($secret === '') {
            return false;
        }

        $authenticated = match ($mode) {
            'token' => $this->verifyToken($secret, $request),
            'hmac_sha256' => $this->verifyHmac($secret, $request),
            default => false,
        };

        if (! $authenticated) {
            return false;
        }

        if ($provider === DeepayKbankPaymentProvider::PROVIDER) {
            return $this->verifyAuthenticatedDeepayCallback($payment, $topup, $request);
        }

        return true;
    }

    private function verifyTrustedDeepayCallback(?object $payment, ?object $topup, Request $request): bool
    {
        if ($payment === null || $topup === null || ! $this->isTrustedDeepaySource($request)) {
            return false;
        }

        $paymentStatus = (string) $payment->status;
        $topupStatus = (string) $topup->status;
        $active = in_array($paymentStatus, ['pending', 'processing'], true)
            && in_array($topupStatus, ['pending', 'processing', 'expired'], true);
        $alreadySucceeded = $paymentStatus === 'succeeded' && $topupStatus === 'succeeded';
        if (! $active && ! $alreadySucceeded) {
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
        $reference4 = trim((string) (
            $payload['reference4']
            ?? data_get($payload, 'payload.reference4', '')
        ));

        $attempt = PaymentProviderAttempt::query()
            ->where('provider', DeepayKbankPaymentProvider::PROVIDER)
            ->where('payment_id', $payment->id)
            ->whereIn('operation', ['bill', 'billCredit'])
            ->latest('attempted_at')
            ->first();
        if ($attempt === null || (string) $attempt->status !== 'succeeded') {
            return false;
        }

        $expectedProviderReference = trim((string) $payment->provider_reference);
        $attemptProviderReference = trim((string) $attempt->provider_transaction_reference);
        $expectedReference1 = trim((string) $attempt->provider_reference1);
        $expectedReference2 = strtolower(trim((string) $attempt->provider_reference2));
        $expectedReference3 = trim((string) $attempt->provider_reference3);
        $expectedReference4 = trim((string) $attempt->provider_reference4);
        if (
            $providerReference === ''
            || $expectedProviderReference === ''
            || $attemptProviderReference === ''
            || $reference1 === ''
            || $reference2 === ''
            || ! hash_equals($expectedProviderReference, $providerReference)
            || ! hash_equals($attemptProviderReference, $providerReference)
            || ! hash_equals($expectedReference1, $reference1)
            || ! hash_equals($expectedReference2, $reference2)
            || ($reference3 !== '' && ! hash_equals($expectedReference3, $reference3))
            || ($reference4 !== '' && ! hash_equals($expectedReference4, $reference4))
        ) {
            return false;
        }

        $amount = $payload['txnAmount']
            ?? $payload['amount']
            ?? data_get($payload, 'payload.txnAmount')
            ?? data_get($payload, 'payload.amount');
        if ($amount !== null && trim((string) $amount) !== '' && $this->amountMinor($amount) !== (int) $payment->amount) {
            return false;
        }

        $currency = strtoupper(trim((string) (
            $payload['txnCurrencyCode']
            ?? $payload['currency']
            ?? data_get($payload, 'payload.txnCurrencyCode')
            ?? data_get($payload, 'payload.currency')
            ?? ''
        )));
        if ($currency !== '' && $currency !== (string) $payment->currency) {
            return false;
        }

        if ($this->deepayCallbackExplicitlyFailed($payload)) {
            return false;
        }

        $tenantId = (string) $payment->tenant_id;

        return (string) $payment->provider === DeepayKbankPaymentProvider::PROVIDER
            && (string) $payment->topup_request_id === (string) $topup->id
            && (string) $topup->payment_id === (string) $payment->id
            && (string) $topup->tenant_id === $tenantId
            && (string) $topup->customer_id === (string) $payment->customer_id
            && (string) $topup->currency === (string) $payment->currency
            && (int) $topup->amount === (int) $payment->amount;
    }

    private function verifyAuthenticatedDeepayCallback(?object $payment, ?object $topup, Request $request): bool
    {
        if ($payment === null || $topup === null) {
            return false;
        }
        $paymentStatus = (string) $payment->status;
        $topupStatus = (string) $topup->status;
        $active = in_array($paymentStatus, ['pending', 'processing'], true)
            && in_array($topupStatus, ['pending', 'processing', 'expired'], true);
        $alreadySucceeded = $paymentStatus === 'succeeded' && $topupStatus === 'succeeded';
        if (! $active && ! $alreadySucceeded) {
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
        $reference4 = trim((string) (
            $payload['reference4']
            ?? data_get($payload, 'payload.reference4', '')
        ));
        $currency = strtoupper(trim((string) (
            $payload['txnCurrencyCode']
            ?? $payload['currency']
            ?? data_get($payload, 'payload.txnCurrencyCode')
            ?? data_get($payload, 'payload.currency')
            ?? ''
        )));
        $amountMinor = $this->amountMinor(
            $payload['txnAmount']
            ?? $payload['amount']
            ?? data_get($payload, 'payload.txnAmount')
            ?? data_get($payload, 'payload.amount'),
        );

        $attempt = PaymentProviderAttempt::query()
            ->where('provider', DeepayKbankPaymentProvider::PROVIDER)
            ->where('payment_id', $payment->id)
            ->whereIn('operation', ['bill', 'billCredit'])
            ->latest('attempted_at')
            ->first();
        if ($attempt === null) {
            return false;
        }

        $expectedReference1 = trim((string) $attempt->provider_reference1);
        $expectedReference2 = strtolower(trim((string) $attempt->provider_reference2));
        $expectedReference3 = trim((string) $attempt->provider_reference3);
        $expectedReference4 = trim((string) $attempt->provider_reference4);
        $expectedProviderReference = trim((string) ($payment->provider_reference ?? $attempt->provider_transaction_reference ?? ''));
        $providerReferenceMatches = $expectedProviderReference !== ''
            ? hash_equals($expectedProviderReference, $providerReference)
            : in_array((string) $attempt->status, ['initiated', 'invalid_response', 'transport_failed', 'outcome_unknown'], true);

        if (
            $providerReference === ''
            || $reference1 === ''
            || $reference3 === ''
            || $reference4 === ''
            || $currency !== 'THB'
            || $amountMinor === null
            || $amountMinor !== (int) $payment->amount
            || ! $this->deepayCallbackDeclaresSuccess($payload)
            || $reference2 !== $expectedReference2
            || ! $providerReferenceMatches
            || ! hash_equals($expectedReference1, $reference1)
            || ! hash_equals($expectedReference3, $reference3)
            || ! hash_equals($expectedReference4, $reference4)
        ) {
            return false;
        }

        $tenantId = (string) $payment->tenant_id;

        return (string) $payment->provider === DeepayKbankPaymentProvider::PROVIDER
            && (string) $payment->topup_request_id === (string) $topup->id
            && (string) $topup->payment_id === (string) $payment->id
            && (string) $topup->tenant_id === $tenantId
            && (string) $topup->customer_id === (string) $payment->customer_id
            && (string) $topup->currency === $currency
            && (int) $topup->amount === $amountMinor;
    }

    /**
     * DeePay does not currently provide an authenticated callback contract in
     * this repository. This check is used only after HMAC/token authentication
     * and deliberately rejects callbacks that merely contain a transaction ID.
     *
     * @param array<string, mixed> $payload
     */
    private function deepayCallbackDeclaresSuccess(array $payload): bool
    {
        $status = strtolower(trim((string) (
            $payload['status']
            ?? $payload['event']
            ?? $payload['txnStatus']
            ?? data_get($payload, 'payload.status')
            ?? data_get($payload, 'payload.txnStatus')
            ?? ''
        )));
        $statusCode = strtoupper(trim((string) (
            $payload['statusCode']
            ?? data_get($payload, 'payload.statusCode')
            ?? ''
        )));

        return in_array($status, ['success', 'succeeded', 'paid', 'payment.succeeded', 'topup.succeeded'], true)
            || $statusCode === '00';
    }

    /**
     * @param array<string, mixed> $payload
     */
    private function deepayCallbackExplicitlyFailed(array $payload): bool
    {
        $status = strtolower(trim((string) (
            $payload['status']
            ?? $payload['event']
            ?? $payload['txnStatus']
            ?? data_get($payload, 'payload.status')
            ?? data_get($payload, 'payload.txnStatus')
            ?? ''
        )));
        if (in_array($status, ['failed', 'failure', 'cancelled', 'canceled', 'expired', 'rejected'], true)) {
            return true;
        }

        $statusCode = strtoupper(trim((string) (
            $payload['statusCode']
            ?? data_get($payload, 'payload.statusCode')
            ?? ''
        )));

        return $statusCode !== '' && ! in_array($statusCode, ['0', '00', '0000'], true);
    }

    private function isTrustedDeepaySource(Request $request): bool
    {
        $trustedIps = config('deepay.callback_trusted_ips', []);
        if (! is_array($trustedIps) || $trustedIps === []) {
            return false;
        }

        $forwardedFor = trim((string) $request->header('X-Forwarded-For', ''));
        $sourceIp = trim(explode(',', $forwardedFor)[0] ?? '');
        if (filter_var($sourceIp, FILTER_VALIDATE_IP) === false) {
            return false;
        }

        foreach ($trustedIps as $trustedIp) {
            $trustedIp = trim((string) $trustedIp);
            if ($trustedIp !== '' && hash_equals($trustedIp, $sourceIp)) {
                return true;
            }
        }

        return false;
    }

    private function amountMinor(mixed $value): ?int
    {
        $value = trim((string) $value);
        if (preg_match('/\A(\d+)(?:\.(\d{1,2}))?\z/', $value, $matches) !== 1) {
            return null;
        }

        $whole = (int) $matches[1];
        $fraction = str_pad((string) ($matches[2] ?? ''), 2, '0');

        return ($whole * 100) + (int) $fraction;
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
