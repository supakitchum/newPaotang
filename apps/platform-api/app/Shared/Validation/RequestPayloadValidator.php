<?php

namespace App\Shared\Validation;

use Illuminate\Http\Request;
use Illuminate\Support\Facades\Validator;

class RequestPayloadValidator
{
    /**
     * @param array<string, mixed> $payload
     * @param array<string, mixed> $rules
     * @param array<string, string> $messages
     * @return array<string, array<int, string>>
     */
    public function validate(array $payload, array $rules, array $messages = []): array
    {
        $validator = Validator::make($payload, $rules, $messages);

        if ($validator->passes()) {
            return [];
        }

        return $validator->errors()->messages();
    }

    /**
     * @return array<string, array<int, string>>
     */
    public function jsonObjectErrors(Request $request): array
    {
        $content = trim($request->getContent());

        if ($content === '') {
            return [];
        }

        $decoded = json_decode($content, true);

        if (! is_array($decoded)) {
            return [
                'payload' => ['The request payload must be a JSON object.'],
            ];
        }

        return [];
    }

    /**
     * @param array<string, mixed> $payload
     * @return array<string, array<int, string>>
     */
    public function requiredString(array $payload, string $field): array
    {
        $value = $payload[$field] ?? null;

        if (! is_string($value) || trim($value) === '') {
            return [
                $field => ['The '.$field.' field is required.'],
            ];
        }

        return [];
    }

    /**
     * @param array<string, mixed> $payload
     * @return array<string, array<int, string>>
     */
    public function optionalString(array $payload, string $field): array
    {
        if (! array_key_exists($field, $payload) || $payload[$field] === null) {
            return [];
        }

        if (! is_string($payload[$field])) {
            return [
                $field => ['The '.$field.' field must be a string.'],
            ];
        }

        return [];
    }

    /**
     * @param array<string, mixed> $payload
     * @return array<string, array<int, string>>
     */
    public function moneyAmount(array $payload, string $field, bool $required = true, bool $allowNegative = false): array
    {
        if (! array_key_exists($field, $payload) || $payload[$field] === null) {
            return $required ? [
                $field => ['The '.$field.' field is required.'],
            ] : [];
        }

        $value = $payload[$field];
        $rawAmount = is_array($value) ? ($value['amount'] ?? null) : $value;
        $errorField = is_array($value) ? $field.'.amount' : $field;

        if (! is_numeric($rawAmount)) {
            return [
                $errorField => ['The '.$errorField.' field must be a valid amount.'],
            ];
        }

        $amount = (int) $rawAmount;

        if ($allowNegative && $amount !== 0) {
            return [];
        }

        if ($amount <= 0) {
            return [
                $errorField => ['The '.$errorField.' field must be greater than zero.'],
            ];
        }

        return [];
    }

    /**
     * @param array<string, mixed> $payload
     * @return array<string, array<int, string>>
     */
    public function dateRange(array $payload): array
    {
        $errors = [];

        foreach (['date_from', 'date_to'] as $field) {
            if (($payload[$field] ?? null) === null || trim((string) $payload[$field]) === '') {
                continue;
            }

            $date = \DateTimeImmutable::createFromFormat('!Y-m-d', (string) $payload[$field]);

            if (! $date instanceof \DateTimeImmutable || $date->format('Y-m-d') !== (string) $payload[$field]) {
                $errors[$field][] = 'The '.$field.' field must be a valid date in Y-m-d format.';
            }
        }

        if ($errors === [] && ($payload['date_from'] ?? null) && ($payload['date_to'] ?? null)) {
            if ((string) $payload['date_to'] < (string) $payload['date_from']) {
                $errors['date_to'][] = 'The date_to field must be after or equal to date_from.';
            }
        }

        return $errors;
    }

    /**
     * @param array<int, array<string, array<int, string>>> $sets
     * @return array<string, array<int, string>>
     */
    public function merge(array ...$sets): array
    {
        $merged = [];

        foreach ($sets as $errors) {
            foreach ($errors as $field => $messages) {
                $merged[$field] = array_values(array_merge($merged[$field] ?? [], $messages));
            }
        }

        return $merged;
    }
}
