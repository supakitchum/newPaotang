<?php

namespace App\Shared\Observability;

class ObservabilityRedactor
{
    /**
     * @param array<string, mixed> $payload
     * @return array<string, mixed>
     */
    public function redact(array $payload): array
    {
        return $this->redactArray($payload, config('platform.audit.sensitive_keys', []));
    }

    /**
     * @param array<string, mixed> $payload
     * @param array<int, string> $sensitiveKeys
     * @return array<string, mixed>
     */
    private function redactArray(array $payload, array $sensitiveKeys): array
    {
        $redacted = [];

        foreach ($payload as $key => $value) {
            if ($this->isSensitiveKey((string) $key, $sensitiveKeys)) {
                $redacted[$key] = '[REDACTED]';
                continue;
            }

            $redacted[$key] = is_array($value) ? $this->redactArray($value, $sensitiveKeys) : $value;
        }

        return $redacted;
    }

    /**
     * @param array<int, string> $sensitiveKeys
     */
    private function isSensitiveKey(string $key, array $sensitiveKeys): bool
    {
        $normalized = strtolower($key);

        foreach ($sensitiveKeys as $sensitiveKey) {
            if (str_contains($normalized, strtolower($sensitiveKey))) {
                return true;
            }
        }

        return false;
    }
}
