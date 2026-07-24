<?php

namespace App\Modules\Commerce\Http\Requests;

use App\Shared\Validation\RequestPayloadValidator;
use Illuminate\Http\UploadedFile;

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

        $reservationIds = $payload['reservation_ids'] ?? null;
        $hasReservationIds = is_array($reservationIds) && array_values(array_filter($reservationIds, fn (mixed $id): bool => trim((string) $id) !== '')) !== [];

        if (trim((string) ($payload['reservation_id'] ?? '')) === '' && ! $hasReservationIds) {
            $errors['reservation_id'][] = 'The reservation_id field is required.';
        }

        if ($reservationIds !== null && ! is_array($reservationIds)) {
            $errors['reservation_ids'][] = 'The reservation_ids field must be an array.';
        }

        if (! in_array((string) ($payload['payment_method'] ?? ''), ['wallet', 'external_payment'], true)) {
            $errors['payment_method'][] = 'The payment_method field is invalid.';
        }

        $assertionToken = trim((string) ($payload['pin_assertion_token'] ?? ''));
        if ($assertionToken === '' && ! preg_match('/^\d{6}$/', trim((string) ($payload['pin'] ?? '')))) {
            $errors['pin'][] = 'The pin field must contain exactly 6 digits.';
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
     * @return array<string, array<int, string>>
     */
    public function topupSlipErrors(?UploadedFile $file): array
    {
        if (! $file instanceof UploadedFile) {
            return [];
        }

        $errors = [];

        if (! $file->isValid()) {
            $errors['slip'][] = 'The slip file could not be uploaded.';
        }

        $mime = (string) ($file->getMimeType() ?: $file->getClientMimeType());
        if (! in_array($mime, ['image/webp', 'image/png', 'image/jpeg'], true)) {
            $errors['slip'][] = 'The slip file must be a webp, png, or jpeg image.';
        }

        if ((int) $file->getSize() > 5 * 1024 * 1024) {
            $errors['slip'][] = 'The slip file must not be larger than 5 MB.';
        }

        return $errors;
    }

    /**
     * @return array<string, array<int, string>>
     */
    public function requiredTopupSlipErrors(?UploadedFile $file): array
    {
        if (! $file instanceof UploadedFile) {
            return ['slip' => ['The slip field is required.']];
        }

        return $this->topupSlipErrors($file);
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
        $errors = $this->payloads->merge(
            $this->payloads->moneyAmount($payload, 'amount', true, true),
            $this->payloads->requiredString($payload, 'reason'),
        );

        if (
            array_key_exists('transaction_type', $payload)
            && ! in_array((string) $payload['transaction_type'], ['deposit', 'withdraw'], true)
        ) {
            $errors['transaction_type'][] = 'The transaction_type field must be deposit or withdraw.';
        }

        return $errors;
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

    /**
     * @param array<string, mixed> $payload
     * @return array<string, array<int, string>>
     */
    public function cancelOrderErrors(array $payload): array
    {
        $errors = $this->payloads->validate($payload, [
            'reason' => ['required', 'string', 'max:2000'],
            'refund_policy' => ['sometimes', 'in:none'],
        ]);

        if (
            array_key_exists('refund_policy', $payload)
            && (string) $payload['refund_policy'] !== 'none'
        ) {
            $errors['refund_policy'] = [
                'Paid orders must be refunded through the dedicated refund endpoint before their financial state can change.',
            ];
        }

        return $errors;
    }

    /**
     * @param array<string, mixed> $payload
     * @return array<string, array<int, string>>
     */
    public function updateOrderErrors(array $payload): array
    {
        $errors = $this->payloads->validate($payload, [
            'reason' => ['required', 'string', 'max:2000'],
            'admin_note' => ['present', 'nullable', 'string', 'max:4000'],
            'status' => ['prohibited'],
            'payment_status' => ['prohibited'],
        ]);

        foreach (['status', 'payment_status'] as $field) {
            if (array_key_exists($field, $payload)) {
                $errors[$field] = [
                    'The '.$field.' field cannot be updated directly. Use the dedicated order lifecycle endpoint.',
                ];
            }
        }

        return $errors;
    }

    /**
     * @param array<string, mixed> $payload
     * @return array<string, array<int, string>>
     */
    public function refundOrderErrors(array $payload): array
    {
        $errors = $this->payloads->merge(
            $this->payloads->moneyAmount($payload, 'amount'),
            $this->payloads->requiredString($payload, 'reason'),
        );
        $amount = $payload['amount'] ?? null;
        $currency = is_array($amount) ? strtoupper(trim((string) ($amount['currency'] ?? ''))) : '';

        if (! is_array($amount) || $currency === '') {
            $errors['amount.currency'][] = 'The amount.currency field is required.';
        } elseif (preg_match('/\A[A-Z]{3}\z/', $currency) !== 1) {
            $errors['amount.currency'][] = 'The amount.currency field must be a valid ISO currency code.';
        }

        if (
            array_key_exists('method', $payload)
            && ! in_array((string) $payload['method'], ['wallet_refund', 'manual_refund', 'original_payment'], true)
        ) {
            $errors['method'][] = 'The method field is invalid.';
        }

        $method = trim((string) ($payload['method'] ?? 'wallet_refund'));
        $reference = trim((string) ($payload['refund_reference'] ?? ''));
        if (is_string($payload['reason'] ?? null) && mb_strlen((string) $payload['reason']) > 2000) {
            $errors['reason'][] = 'The reason field must not be greater than 2000 characters.';
        }
        if (in_array($method, ['manual_refund', 'original_payment'], true) && $reference === '') {
            $errors['refund_reference'][] = 'The refund_reference field is required for an external refund.';
        } elseif (mb_strlen($reference) > 191) {
            $errors['refund_reference'][] = 'The refund_reference field must not be greater than 191 characters.';
        } elseif ($method === 'wallet_refund' && $reference !== '') {
            $errors['refund_reference'][] = 'The refund_reference field must be empty for a wallet refund.';
        }

        return $errors;
    }

    private function rawAmount(mixed $value): ?int
    {
        $raw = is_array($value) ? ($value['amount'] ?? null) : $value;

        return is_numeric($raw) ? (int) $raw : null;
    }
}
