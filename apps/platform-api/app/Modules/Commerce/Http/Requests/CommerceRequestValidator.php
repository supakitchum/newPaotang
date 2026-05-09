<?php

namespace App\Modules\Commerce\Http\Requests;

use App\Shared\Validation\RequestPayloadValidator;

class CommerceRequestValidator
{
    public function __construct(private readonly RequestPayloadValidator $payloads)
    {
    }

    /**
     * @param array<string, mixed> $payload
     * @return array<string, array<int, string>>
     */
    public function checkoutErrors(array $payload): array
    {
        $errors = [];

        if (trim((string) ($payload['reservation_id'] ?? '')) === '') {
            $errors['reservation_id'][] = 'The reservation_id field is required.';
        }

        if (! in_array((string) ($payload['payment_method'] ?? ''), ['wallet', 'external_payment'], true)) {
            $errors['payment_method'][] = 'The payment_method field is invalid.';
        }

        return $errors;
    }

    /**
     * @param array<string, mixed> $payload
     * @return array<string, array<int, string>>
     */
    public function customerTopupErrors(array $payload, bool $credit = false): array
    {
        $errors = $this->payloads->moneyAmount($payload, 'amount');
        $amount = $this->rawAmount($payload['amount'] ?? null);

        if ($amount !== null && $credit && $amount < 400) {
            $errors['amount'][] = 'The amount field must be at least 400.';
        }

        $channel = $credit ? 'credit_card' : (string) ($payload['channel'] ?? '');

        if (! in_array($channel, ['qr', 'bank_transfer', 'credit_card'], true)) {
            $errors['channel'][] = 'The channel field is invalid.';
        }

        return $errors;
    }

    /**
     * @param array<string, mixed> $payload
     * @return array<string, array<int, string>>
     */
    public function reservationErrors(array $payload): array
    {
        $errors = [];

        if (trim((string) ($payload['game_id'] ?? '')) === '') {
            $errors['game_id'][] = 'The game_id field is required.';
        }

        if (! is_array($payload['local_stock_item_ids'] ?? null) || count($payload['local_stock_item_ids']) < 1) {
            $errors['local_stock_item_ids'][] = 'The local_stock_item_ids field is required.';
        }

        return $errors;
    }

    /**
     * @param array<string, mixed> $payload
     * @return array<string, array<int, string>>
     */
    public function walletAdjustmentErrors(array $payload): array
    {
        return $this->payloads->merge(
            $this->payloads->moneyAmount($payload, 'amount', true, true),
            $this->payloads->requiredString($payload, 'reason'),
        );
    }

    /**
     * @param array<string, mixed> $payload
     * @return array<string, array<int, string>>
     */
    public function reviewReasonErrors(array $payload): array
    {
        return $this->payloads->requiredString($payload, 'reason');
    }

    /**
     * @param array<string, mixed> $payload
     * @return array<string, array<int, string>>
     */
    public function optionalReasonErrors(array $payload): array
    {
        return $this->payloads->optionalString($payload, 'reason');
    }

    private function rawAmount(mixed $value): ?int
    {
        $raw = is_array($value) ? ($value['amount'] ?? null) : $value;

        return is_numeric($raw) ? (int) $raw : null;
    }
}
