<?php

namespace App\Modules\Reward\Http\Requests;

use App\Modules\Reward\Services\RewardService;
use App\Shared\Validation\RequestPayloadValidator;

class RewardClaimRequestValidator
{
    public function __construct(private readonly RequestPayloadValidator $payloads)
    {
    }

    /**
     * @param array<string, mixed> $payload
     * @return array<string, array<int, string>>
     */
    public function customerClaimErrors(array $payload): array
    {
        $errors = [];

        if (trim((string) ($payload['ticket_id'] ?? '')) === '') {
            $errors['ticket_id'][] = 'The ticket_id field is required.';
        }

        $method = (string) ($payload['payout_method'] ?? '');

        if (! in_array($method, ['wallet_credit', 'bank_transfer'], true)) {
            $errors['payout_method'][] = 'The payout_method field must be one of wallet_credit, bank_transfer.';
        }

        return $errors;
    }

    /**
     * @param array<string, mixed> $payload
     * @return array<string, array<int, string>>
     */
    public function tenantClaimActionErrors(array $payload, string $action): array
    {
        $errors = $this->payloads->requiredString($payload, 'reason');

        if ($action === 'approve') {
            $errors = $this->payloads->merge($errors, $this->positiveMoneyOverride($payload, 'approved_amount'));
        }

        if ($action === 'pay') {
            $method = $payload['payout_method'] ?? null;

            if (! is_string($method) || ! in_array(trim($method), RewardService::CLAIM_PAYOUT_METHODS, true)) {
                $errors['payout_method'][] = 'The payout_method field must be one of wallet_credit, bank_transfer, manual_cash.';
            }

            $errors = $this->payloads->merge($errors, $this->positiveMoneyOverride($payload, 'paid_amount'));
        }

        return $errors;
    }

    /**
     * @param array<string, mixed> $payload
     * @return array<string, array<int, string>>
     */
    private function positiveMoneyOverride(array $payload, string $field): array
    {
        if (! array_key_exists($field, $payload) || $payload[$field] === null) {
            return [];
        }

        $value = $payload[$field];
        $rawAmount = is_array($value) ? ($value['amount'] ?? null) : $value;

        if (! is_numeric($rawAmount)) {
            return [
                $field.'.amount' => ['The '.$field.'.amount field must be a valid amount.'],
            ];
        }

        if ((int) $rawAmount <= 0) {
            return [
                $field.'.amount' => ['The '.$field.'.amount field must be greater than zero.'],
            ];
        }

        return [];
    }
}
