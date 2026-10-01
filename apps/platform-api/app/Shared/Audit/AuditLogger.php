<?php

namespace App\Shared\Audit;

use App\Models\AuditLog;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Str;

class AuditLogger
{
    /**
     * @param array<string, mixed> $payload
     */
    public function logAdminWrite(
        string $actorId,
        string $scopeType,
        string $action,
        string $targetType,
        ?string $targetId,
        array $payload,
        ?string $tenantId = null,
        ?string $partnerId = null,
        ?string $requestId = null,
        ?string $ipAddress = null,
        ?string $userAgent = null,
    ): string {
        $id = 'aud_'.Str::ulid()->toBase32();

        AuditLog::query()->insert([
            'id' => $id,
            'actor_type' => 'admin',
            'actor_id' => $actorId,
            'scope_type' => $scopeType,
            'tenant_id' => $tenantId,
            'partner_id' => $partnerId,
            'action' => $action,
            'target_type' => $targetType,
            'target_id' => $targetId,
            'request_id' => $requestId,
            'ip_address' => $ipAddress,
            'user_agent' => $userAgent,
            'payload_redacted_json' => json_encode($this->redactPayload($payload), JSON_THROW_ON_ERROR),
            'created_at' => now(),
            'updated_at' => now(),
        ]);

        return $id;
    }

    /**
     * @param array<string, mixed> $payload
     * @return array<string, mixed>
     */
    public function redactPayload(array $payload): array
    {
        $sensitiveKeys = config('platform.audit.sensitive_keys', []);

        return $this->redactArray($payload, $sensitiveKeys);
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
