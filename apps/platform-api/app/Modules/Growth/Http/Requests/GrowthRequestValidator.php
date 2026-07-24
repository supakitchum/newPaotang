<?php

namespace App\Modules\Growth\Http\Requests;

use App\Shared\Validation\RequestPayloadValidator;

class GrowthRequestValidator
{
    private const PAYOUT_METHODS = ['bank_transfer', 'manual_cash', 'wallet_credit'];

    public function __construct(private readonly RequestPayloadValidator $payloads)
    {
    }

    /**
     * @param array<string, mixed> $payload
     * @return array<string, array<int, string>>
     */
    public function payoutCreateErrors(array $payload): array
    {
        $errors = [];
        $affiliateId = trim((string) ($payload['affiliate_account_id'] ?? $payload['affiliate_id'] ?? ''));
        $method = (string) ($payload['payout_method'] ?? 'bank_transfer');

        if ($affiliateId === '') {
            $errors['affiliate_id'][] = 'The affiliate_id field is required.';
        }

        $errors = $this->payloads->merge($errors, $this->affiliatePayoutAmountErrors($payload));

        if (! in_array($method, self::PAYOUT_METHODS, true)) {
            $errors['payout_method'][] = 'The payout_method field is invalid.';
        }

        return $errors;
    }

    /**
     * @param array<string, mixed> $payload
     * @return array<string, array<int, string>>
     */
    public function customerPayoutCreateErrors(array $payload): array
    {
        $method = (string) ($payload['payout_method'] ?? 'bank_transfer');
        $errors = $this->affiliatePayoutAmountErrors($payload);

        if (! in_array($method, self::PAYOUT_METHODS, true)) {
            $errors['payout_method'][] = 'The payout_method field is invalid.';
        }

        return $errors;
    }

    /**
     * @param array<string, mixed> $payload
     * @return array<string, array<int, string>>
     */
    public function optionalApprovalReasonErrors(array $payload): array
    {
        return $this->payloads->optionalString($payload, 'reason');
    }

    /**
     * @param array<string, mixed> $payload
     * @return array<string, array<int, string>>
     */
    public function payoutPaymentErrors(array $payload): array
    {
        $errors = $this->optionalApprovalReasonErrors($payload);
        $reference = trim((string) (
            $payload['payment_reference']
            ?? $payload['transfer_reference']
            ?? $payload['reference']
            ?? ''
        ));

        if ($reference === '') {
            $errors['payment_reference'][] = 'The payment_reference field is required.';
        } elseif (mb_strlen($reference) > 191) {
            $errors['payment_reference'][] = 'The payment_reference field must not be greater than 191 characters.';
        } elseif (preg_match('/[\x00-\x1F\x7F]/u', $reference) === 1) {
            $errors['payment_reference'][] = 'The payment_reference field contains invalid characters.';
        }

        return $errors;
    }

    /**
     * Affiliate balances use integer minor units. Reject fractional and
     * scientific-notation input instead of silently coercing it.
     *
     * @param array<string, mixed> $payload
     * @return array<string, array<int, string>>
     */
    private function affiliatePayoutAmountErrors(array $payload): array
    {
        if (! array_key_exists('amount', $payload) || $payload['amount'] === null) {
            return ['amount' => ['The amount field is required.']];
        }

        $value = $payload['amount'];
        $rawAmount = is_array($value) ? ($value['amount'] ?? null) : $value;
        $errorField = is_array($value) ? 'amount.amount' : 'amount';
        $isInteger = is_int($rawAmount)
            || (is_float($rawAmount) && is_finite($rawAmount) && floor($rawAmount) === $rawAmount)
            || (is_string($rawAmount) && preg_match('/^[0-9]+$/D', $rawAmount) === 1);

        if (! $isInteger) {
            return [
                $errorField => ['The '.$errorField.' field must be a whole minor-unit amount.'],
            ];
        }

        if ((int) $rawAmount <= 0) {
            return [
                $errorField => ['The '.$errorField.' field must be greater than zero.'],
            ];
        }

        return [];
    }
}
