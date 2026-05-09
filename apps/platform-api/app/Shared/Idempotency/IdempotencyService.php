<?php

namespace App\Shared\Idempotency;

use App\Models\IdempotencyKey;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Str;

class IdempotencyService
{
    /**
     * @param array<string, mixed> $payload
     * @return array{status: int, body: array<string, mixed>|null}|string|null
     */
    public function replayOrConflict(
        ?string $tenantId,
        string $actorType,
        string $actorId,
        string $routeKey,
        string $idempotencyKey,
        array $payload,
        ?string $permissionCode = null,
        bool $lock = false,
    ): array|string|null {
        $query = IdempotencyKey::query()
            ->where('tenant_id', $tenantId)
            ->where('actor_type', $actorType)
            ->where('actor_id', $actorId)
            ->where('route_key', $routeKey)
            ->where('idempotency_key', $idempotencyKey);

        if ($lock) {
            $query->lockForUpdate();
        }

        $record = $query->first();

        if ($record === null) {
            return null;
        }

        if ($record->payload_hash !== $this->payloadHash($payload)) {
            return 'idempotency_conflict';
        }

        if ($record->response_status === null) {
            return 'resource_conflict';
        }

        return [
            'status' => (int) $record->response_status,
            'body' => $this->decodeJsonObject($record->response_body_json),
        ];
    }

    /**
     * @param array<string, mixed> $payload
     * @param array<string, mixed>|null $responseBody
     */
    public function storeResponse(
        ?string $tenantId,
        string $actorType,
        string $actorId,
        string $routeKey,
        string $idempotencyKey,
        array $payload,
        int $responseStatus,
        ?array $responseBody,
        ?string $permissionCode = null,
    ): void {
        IdempotencyKey::query()->updateOrInsert(
            [
                'tenant_id' => $tenantId,
                'actor_type' => $actorType,
                'actor_id' => $actorId,
                'route_key' => $routeKey,
                'idempotency_key' => $idempotencyKey,
            ],
            [
                'id' => 'idk_'.Str::ulid()->toBase32(),
                'permission_code' => $permissionCode,
                'payload_hash' => $this->payloadHash($payload),
                'response_status' => $responseStatus,
                'response_body_json' => $responseBody === null ? null : json_encode($responseBody, JSON_THROW_ON_ERROR),
                'completed_at' => now(),
                'expires_at' => now()->addDays(30),
                'created_at' => now(),
                'updated_at' => now(),
            ],
        );
    }

    /**
     * @param array<string, mixed> $payload
     */
    public function payloadHash(array $payload): string
    {
        return hash('sha256', json_encode($this->normalizePayload($payload), JSON_THROW_ON_ERROR));
    }

    /**
     * @param array<string, mixed> $payload
     * @return array<string, mixed>
     */
    private function normalizePayload(array $payload): array
    {
        ksort($payload);

        foreach ($payload as $key => $value) {
            if (is_array($value)) {
                $payload[$key] = $this->normalizePayload($value);
            }
        }

        return $payload;
    }

    /**
     * @return array<string, mixed>|null
     */
    private function decodeJsonObject(mixed $json): ?array
    {
        if (is_array($json)) {
            return $json;
        }

        if ($json === null || $json === '') {
            return null;
        }

        $decoded = json_decode((string) $json, true);

        return is_array($decoded) ? $decoded : null;
    }
}
