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

        $errors = $this->payloads->merge($errors, $this->payloads->moneyAmount($payload, 'amount'));

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
}
