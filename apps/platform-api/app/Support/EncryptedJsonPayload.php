<?php

namespace App\Support;

use Illuminate\Contracts\Encryption\DecryptException;
use Illuminate\Support\Facades\Crypt;
use RuntimeException;

final class EncryptedJsonPayload
{
    /**
     * @param array<string, mixed> $payload
     */
    public static function encrypt(array $payload): ?string
    {
        if ($payload === []) {
            return null;
        }

        return Crypt::encryptString(json_encode(
            $payload,
            JSON_THROW_ON_ERROR | JSON_UNESCAPED_UNICODE | JSON_UNESCAPED_SLASHES,
        ));
    }

    /**
     * @return array<string, mixed>
     */
    public static function decrypt(mixed $encrypted, mixed $legacy = null): array
    {
        if (is_array($encrypted)) {
            return $encrypted;
        }

        if (is_string($encrypted) && trim($encrypted) !== '') {
            try {
                $plain = Crypt::decryptString($encrypted);
            } catch (DecryptException $exception) {
                throw new RuntimeException('Sensitive JSON payload cannot be decrypted.', previous: $exception);
            }

            return self::decode($plain, true);
        }

        return self::decode($legacy, false);
    }

    /**
     * @param array<string, mixed> $bankAccount
     * @return array<string, mixed>
     */
    public static function maskedBankAccount(array $bankAccount): array
    {
        if ($bankAccount === []) {
            return [];
        }

        $masked = $bankAccount;
        $accountNumber = trim((string) ($bankAccount['account_number'] ?? ''));
        if ($accountNumber === '') {
            return $masked;
        }

        $digits = preg_replace('/\D+/', '', $accountNumber) ?? '';
        $tail = $digits === ''
            ? mb_substr($accountNumber, -4)
            : substr($digits, -4);
        $maskedNumber = '******'.$tail;
        $masked['account_number'] = $maskedNumber;
        $masked['account_number_masked'] = $maskedNumber;
        $masked['account_number_last_four'] = $tail;

        return $masked;
    }

    /**
     * @return array<string, mixed>
     */
    private static function decode(mixed $value, bool $strict): array
    {
        if (is_array($value)) {
            return $value;
        }

        if ($value === null || $value === '') {
            return [];
        }

        try {
            $decoded = json_decode((string) $value, true, flags: JSON_THROW_ON_ERROR);
        } catch (\JsonException $exception) {
            if ($strict) {
                throw new RuntimeException('Sensitive JSON payload is invalid.', previous: $exception);
            }

            return [];
        }

        if (! is_array($decoded)) {
            if ($strict) {
                throw new RuntimeException('Sensitive JSON payload must decode to an object.');
            }

            return [];
        }

        return $decoded;
    }
}
