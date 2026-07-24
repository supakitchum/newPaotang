<?php

namespace App\Services;

use App\Auth\SupportActorContext;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Str;

class SupportAuditService
{
    /**
     * @param array<string, mixed> $metadata
     */
    public function record(
        SupportActorContext $context,
        string $action,
        string $subjectType,
        string $subjectId,
        array $metadata = [],
    ): void {
        DB::table('support_audit_logs')->insert([
            'id' => 'sal_'.Str::ulid()->toBase32(),
            'tenant_id' => $context->tenantId(),
            'actor_type' => $context->actorType(),
            'actor_external_id' => $context->actor->external_id,
            'action' => $action,
            'subject_type' => $subjectType,
            'subject_id' => $subjectId,
            'metadata_json' => $metadata === []
                ? null
                : json_encode(
                    $metadata,
                    JSON_UNESCAPED_UNICODE | JSON_UNESCAPED_SLASHES,
                ),
            'request_id' => trim((string) request()->header('X-Request-ID')) ?: null,
            'created_at' => now(),
            'updated_at' => now(),
        ]);
    }
}
