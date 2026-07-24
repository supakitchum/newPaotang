<?php

namespace App\Services;

use App\Auth\SupportActorContext;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Str;
use RuntimeException;

class SupportIdempotencyService
{
    /**
     * @param array<string, mixed> $payload
     * @return array{status: int, body: array<string, mixed>}|null
     */
    public function replay(
        SupportActorContext $context,
        string $operation,
        string $key,
        array $payload,
    ): ?array {
        $record = DB::table('support_idempotency_records')
            ->where('tenant_id', $context->tenantId())
            ->where('actor_id', $context->actor->id)
            ->where('operation', $operation)
            ->where('idempotency_key', $key)
            ->first();
        if ($record === null) {
            return null;
        }

        if (! hash_equals((string) $record->payload_hash, $this->payloadHash($payload))) {
            throw new RuntimeException('idempotency_conflict');
        }

        if ($record->response_status === null || $record->response_json === null) {
            throw new RuntimeException('idempotency_in_progress');
        }

        $body = json_decode((string) $record->response_json, true);

        return [
            'status' => (int) $record->response_status,
            'body' => is_array($body) ? $body : [],
        ];
    }

    /**
     * @param array<string, mixed> $payload
     * @return array{status: int, body: array<string, mixed>}|null
     */
    public function begin(
        SupportActorContext $context,
        string $operation,
        string $key,
        array $payload,
    ): ?array {
        $inserted = DB::table('support_idempotency_records')->insertOrIgnore([
            'id' => 'sid_'.Str::ulid()->toBase32(),
            'tenant_id' => $context->tenantId(),
            'actor_id' => $context->actor->id,
            'operation' => $operation,
            'idempotency_key' => $key,
            'payload_hash' => $this->payloadHash($payload),
            'created_at' => now(),
            'updated_at' => now(),
        ]);
        if ($inserted === 1) {
            return null;
        }

        return $this->replay($context, $operation, $key, $payload);
    }

    /**
     * @param array<string, mixed> $body
     */
    public function finish(
        SupportActorContext $context,
        string $operation,
        string $key,
        int $status,
        array $body,
    ): void {
        DB::table('support_idempotency_records')
            ->where('tenant_id', $context->tenantId())
            ->where('actor_id', $context->actor->id)
            ->where('operation', $operation)
            ->where('idempotency_key', $key)
            ->update([
                'response_status' => $status,
                'response_json' => json_encode($body, JSON_UNESCAPED_UNICODE | JSON_UNESCAPED_SLASHES),
                'updated_at' => now(),
            ]);
    }

    /**
     * @param array<string, mixed> $payload
     */
    public function abandon(
        SupportActorContext $context,
        string $operation,
        string $key,
        array $payload,
    ): void {
        DB::table('support_idempotency_records')
            ->where('tenant_id', $context->tenantId())
            ->where('actor_id', $context->actor->id)
            ->where('operation', $operation)
            ->where('idempotency_key', $key)
            ->where('payload_hash', $this->payloadHash($payload))
            ->whereNull('response_status')
            ->delete();
    }

    /**
     * @param array<string, mixed> $payload
     */
    private function payloadHash(array $payload): string
    {
        $this->sortRecursively($payload);

        return hash('sha256', json_encode($payload, JSON_UNESCAPED_UNICODE | JSON_UNESCAPED_SLASHES));
    }

    /**
     * @param array<string|int, mixed> $payload
     */
    private function sortRecursively(array &$payload): void
    {
        foreach ($payload as &$value) {
            if (is_array($value)) {
                $this->sortRecursively($value);
            }
        }
        unset($value);

        if (! array_is_list($payload)) {
            ksort($payload);
        }
    }
}
