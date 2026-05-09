<?php

namespace App\Modules\SupportAccess\Services;

use App\Models\PartnerTenant;
use App\Models\SupportAccessApproval;
use App\Models\SupportAccessRequest;
use App\Models\SupportImpersonationBlockedAction;
use App\Models\SupportImpersonationEvent;
use App\Models\SupportImpersonationSession;
use App\Models\SyncOutbox;
use App\Shared\Audit\AuditLogger;
use App\Shared\Auth\AdminSessionContext;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Str;

class SupportAccessService
{
    private const SESSION_TTL_MINUTES = 30;
    private const REQUEST_TTL_HOURS = 24;

    public function __construct(private readonly AuditLogger $auditLogger)
    {
    }

    /**
     * @param array<string, mixed> $queryParams
     * @return array{data: array<int, array<string, mixed>>, meta: array<string, mixed>}
     */
    public function listRequests(string $tenantId, array $queryParams): array
    {
        $this->expireRequests($tenantId);
        $limit = $this->limit($queryParams['limit'] ?? null);
        $query = SupportAccessRequest::query()
            ->forTenant($tenantId)
            ->orderBy('id')
            ->limit($limit + 1);

        if (($queryParams['status'] ?? null) !== null && trim((string) $queryParams['status']) !== '') {
            $query->where('status', trim((string) $queryParams['status']));
        }

        if (($queryParams['cursor'] ?? null) !== null && trim((string) $queryParams['cursor']) !== '') {
            $query->where('id', '>', trim((string) $queryParams['cursor']));
        }

        $rows = $query->get()->all();
        $hasMore = count($rows) > $limit;
        $rows = array_slice($rows, 0, $limit);

        return [
            'data' => array_map(fn (object $row): array => $this->requestResource($row), $rows),
            'meta' => [
                'next_cursor' => $hasMore && $rows !== [] ? (string) end($rows)->id : null,
                'has_more' => $hasMore,
            ],
        ];
    }

    /**
     * @return array<string, mixed>|null
     */
    public function findRequest(string $tenantId, string $supportAccessId): ?array
    {
        $this->expireRequests($tenantId);
        $request = SupportAccessRequest::query()->forTenant($tenantId)->where('id', $supportAccessId)->first();

        return $request === null ? null : $this->requestResource($request, true);
    }

    /**
     * @param array<string, mixed> $payload
     * @return array<string, mixed>|string
     */
    public function createRequest(string $tenantId, array $payload, AdminSessionContext $actor, Request $httpRequest): array|string
    {
        return DB::transaction(function () use ($tenantId, $payload, $actor, $httpRequest): array|string {
            $tenant = PartnerTenant::find($tenantId);

            if ($tenant === null) {
                return 'not_found';
            }

            $now = now();
            $supportAccessId = 'sar_'.Str::ulid()->toBase32();

            SupportAccessRequest::query()->insert([
                'id' => $supportAccessId,
                'tenant_id' => $tenantId,
                'target_user_id' => (string) $payload['target_user_id'],
                'target_user_type' => (string) $payload['target_user_type'],
                'scope' => (string) $payload['scope'],
                'status' => 'pending_approval',
                'reason' => (string) $payload['reason'],
                'ticket_id' => (string) $payload['ticket_id'],
                'requested_by_admin_id' => $actor->adminUser['id'],
                'approved_by_admin_id' => null,
                'approved_at' => null,
                'revoked_by_admin_id' => null,
                'revoked_at' => null,
                'completed_at' => null,
                'expires_at' => $now->copy()->addHours(self::REQUEST_TTL_HOURS),
                'metadata_json' => json_encode(['request_id' => $httpRequest->header('X-Request-Id')], JSON_THROW_ON_ERROR),
                'created_at' => $now,
                'updated_at' => $now,
            ]);

            $this->insertApprovalEvent($tenantId, $supportAccessId, 'requested', 'accepted', (string) $payload['reason'], $actor, $payload);
            $this->insertImpersonationEvent($tenantId, $supportAccessId, null, 'support_access.requested', null, $actor, $payload);
            $this->auditSupportAccess($actor, $httpRequest, 'support_access.requested', 'support_access_request', $supportAccessId, $tenant, $payload);

            return $this->requestResource(SupportAccessRequest::find($supportAccessId), true);
        });
    }

    /**
     * @param array<string, mixed> $payload
     * @return array<string, mixed>|string
     */
    public function approve(string $tenantId, string $supportAccessId, array $payload, AdminSessionContext $actor, Request $httpRequest): array|string
    {
        return DB::transaction(function () use ($tenantId, $supportAccessId, $payload, $actor, $httpRequest): array|string {
            $request = SupportAccessRequest::query()
                ->where('tenant_id', $tenantId)
                ->where('id', $supportAccessId)
                ->lockForUpdate()
                ->first();

            if ($request === null) {
                return 'not_found';
            }

            if (! in_array($request->status, ['pending_approval', 'approved'], true)) {
                return 'resource_conflict';
            }

            if ($request->status !== 'approved') {
                SupportAccessRequest::query()->where('id', $supportAccessId)->update([
                    'status' => 'approved',
                    'approved_by_admin_id' => $actor->adminUser['id'],
                    'approved_at' => now(),
                    'updated_at' => now(),
                ]);

                $this->insertApprovalEvent($tenantId, $supportAccessId, 'approved', 'accepted', (string) $payload['reason'], $actor, $payload);
                $this->insertImpersonationEvent($tenantId, $supportAccessId, null, 'support_access.approved', null, $actor, $payload);
            }

            $tenant = PartnerTenant::find($tenantId);
            $this->auditSupportAccess($actor, $httpRequest, 'support_access.approved', 'support_access_request', $supportAccessId, $tenant, $payload);

            return $this->requestResource(SupportAccessRequest::find($supportAccessId), true);
        });
    }

    /**
     * @param array<string, mixed> $payload
     * @return array<string, mixed>|string
     */
    public function revoke(string $tenantId, string $supportAccessId, array $payload, AdminSessionContext $actor, Request $httpRequest): array|string
    {
        return DB::transaction(function () use ($tenantId, $supportAccessId, $payload, $actor, $httpRequest): array|string {
            $request = SupportAccessRequest::query()
                ->where('tenant_id', $tenantId)
                ->where('id', $supportAccessId)
                ->lockForUpdate()
                ->first();

            if ($request === null) {
                return 'not_found';
            }

            if (! in_array($request->status, ['pending_approval', 'approved', 'revoked'], true)) {
                return 'resource_conflict';
            }

            if ($request->status !== 'revoked') {
                SupportAccessRequest::query()->where('id', $supportAccessId)->update([
                    'status' => 'revoked',
                    'revoked_by_admin_id' => $actor->adminUser['id'],
                    'revoked_at' => now(),
                    'updated_at' => now(),
                ]);

                SupportImpersonationSession::query()
                    ->where('tenant_id', $tenantId)
                    ->where('support_access_request_id', $supportAccessId)
                    ->where('status', 'active')
                    ->update([
                        'status' => 'revoked',
                        'revoked_at' => now(),
                        'updated_at' => now(),
                    ]);

                $this->insertApprovalEvent($tenantId, $supportAccessId, 'revoked', 'accepted', (string) $payload['reason'], $actor, $payload);
                $this->insertImpersonationEvent($tenantId, $supportAccessId, null, 'support_access.revoked', null, $actor, $payload);
            }

            $tenant = PartnerTenant::find($tenantId);
            $this->auditSupportAccess($actor, $httpRequest, 'support_access.revoked', 'support_access_request', $supportAccessId, $tenant, $payload);

            return $this->requestResource(SupportAccessRequest::find($supportAccessId), true);
        });
    }

    /**
     * @param array<string, mixed> $payload
     * @return array{resource?: array<string, mixed>, token?: string, error?: string}
     */
    public function startImpersonation(string $tenantId, string $supportAccessId, array $payload, AdminSessionContext $actor, Request $httpRequest): array
    {
        return DB::transaction(function () use ($tenantId, $supportAccessId, $payload, $actor, $httpRequest): array {
            $request = SupportAccessRequest::query()
                ->where('tenant_id', $tenantId)
                ->where('id', $supportAccessId)
                ->lockForUpdate()
                ->first();

            if ($request === null) {
                return ['error' => 'not_found'];
            }

            if ($request->status !== 'approved' || ($request->expires_at !== null && strtotime((string) $request->expires_at) <= now()->timestamp)) {
                return ['error' => 'resource_conflict'];
            }

            $activeSession = SupportImpersonationSession::query()
                ->where('tenant_id', $tenantId)
                ->where('support_access_request_id', $supportAccessId)
                ->where('status', 'active')
                ->where('expires_at', '>', now())
                ->first();

            if ($activeSession !== null) {
                return ['error' => 'resource_conflict'];
            }

            $now = now();
            $sessionId = 'imp_'.Str::ulid()->toBase32();
            $token = 'npa_sup_'.Str::random(48);
            $expiresAt = $now->copy()->addMinutes(self::SESSION_TTL_MINUTES);

            SupportImpersonationSession::query()->insert([
                'id' => $sessionId,
                'tenant_id' => $tenantId,
                'support_access_request_id' => $supportAccessId,
                'target_user_id' => (string) $request->target_user_id,
                'target_user_type' => (string) $request->target_user_type,
                'scope' => (string) $request->scope,
                'status' => 'active',
                'token_hash' => hash('sha256', $token),
                'token_last_four' => substr($token, -4),
                'issued_to_admin_id' => $actor->adminUser['id'],
                'started_at' => $now,
                'expires_at' => $expiresAt,
                'revoked_at' => null,
                'ended_at' => null,
                'metadata_json' => json_encode(['reason' => $payload['reason'] ?? null], JSON_THROW_ON_ERROR),
                'created_at' => $now,
                'updated_at' => $now,
            ]);

            $this->insertImpersonationEvent($tenantId, $supportAccessId, $sessionId, 'support_impersonation.started', null, $actor, $payload);
            $this->insertOutboxStarted($request, $sessionId, $actor, $httpRequest, $expiresAt);
            $tenant = PartnerTenant::find($tenantId);
            $this->auditSupportAccess($actor, $httpRequest, 'support_impersonation.started', 'support_impersonation_session', $sessionId, $tenant, [
                'support_access_request_id' => $supportAccessId,
                'reason' => $payload['reason'] ?? null,
                'token_last_four' => substr($token, -4),
            ]);

            $fresh = SupportAccessRequest::find($supportAccessId);
            $session = SupportImpersonationSession::find($sessionId);

            return [
                'resource' => $this->requestResource($fresh, true, $this->sessionResource($session, $token)),
                'token' => $token,
            ];
        });
    }

    /**
     * @param array<string, mixed> $payload
     * @return array<string, mixed>|string
     */
    public function recordElevatedAction(string $tenantId, string $supportAccessId, array $payload, AdminSessionContext $actor, Request $httpRequest): array|string
    {
        return DB::transaction(function () use ($tenantId, $supportAccessId, $payload, $actor, $httpRequest): array|string {
            $request = SupportAccessRequest::query()->forTenant($tenantId)->where('id', $supportAccessId)->first();

            if ($request === null) {
                return 'not_found';
            }

            if (! in_array($request->status, ['approved', 'completed'], true)) {
                return 'resource_conflict';
            }

            $activeSession = SupportImpersonationSession::query()
                ->where('tenant_id', $tenantId)
                ->where('support_access_request_id', $supportAccessId)
                ->where('status', 'active')
                ->where('expires_at', '>', now())
                ->orderByDesc('created_at')
                ->first();

            $this->insertImpersonationEvent(
                $tenantId,
                $supportAccessId,
                $activeSession->id ?? null,
                'support_impersonation.elevated_action',
                (string) $payload['action'],
                $actor,
                $payload,
            );

            $tenant = PartnerTenant::find($tenantId);
            $this->auditSupportAccess($actor, $httpRequest, 'support_access.elevated_action', 'support_access_request', $supportAccessId, $tenant, $payload);

            return $this->requestResource(SupportAccessRequest::find($supportAccessId), true);
        });
    }

    /**
     * @param array<string, mixed> $payload
     * @return array<string, mixed>|string
     */
    public function endSession(string $tenantId, string $supportAccessId, array $payload, AdminSessionContext $actor, Request $httpRequest): array|string
    {
        return DB::transaction(function () use ($tenantId, $supportAccessId, $payload, $actor, $httpRequest): array|string {
            $request = SupportAccessRequest::query()
                ->where('tenant_id', $tenantId)
                ->where('id', $supportAccessId)
                ->lockForUpdate()
                ->first();

            if ($request === null) {
                return 'not_found';
            }

            if (! in_array($request->status, ['approved', 'completed'], true)) {
                return 'resource_conflict';
            }

            SupportImpersonationSession::query()
                ->where('tenant_id', $tenantId)
                ->where('support_access_request_id', $supportAccessId)
                ->where('status', 'active')
                ->update([
                    'status' => 'ended',
                    'ended_at' => now(),
                    'updated_at' => now(),
                ]);

            SupportAccessRequest::query()->where('id', $supportAccessId)->update([
                'status' => 'completed',
                'completed_at' => now(),
                'updated_at' => now(),
            ]);

            $this->insertApprovalEvent($tenantId, $supportAccessId, 'ended_session', 'accepted', (string) $payload['reason'], $actor, $payload);
            $this->insertImpersonationEvent($tenantId, $supportAccessId, null, 'support_impersonation.ended', null, $actor, $payload);
            $tenant = PartnerTenant::find($tenantId);
            $this->auditSupportAccess($actor, $httpRequest, 'support_impersonation.ended', 'support_access_request', $supportAccessId, $tenant, $payload);

            return $this->requestResource(SupportAccessRequest::find($supportAccessId), true);
        });
    }

    public function validateSessionToken(string $tenantId, string $sessionId, string $token): ?object
    {
        if ($tenantId === '' || $sessionId === '' || $token === '') {
            return null;
        }

        return SupportImpersonationSession::query()
            ->join('support_access_requests', 'support_access_requests.id', '=', 'support_impersonation_sessions.support_access_request_id')
            ->where('support_impersonation_sessions.tenant_id', $tenantId)
            ->where('support_impersonation_sessions.id', $sessionId)
            ->where('support_impersonation_sessions.status', 'active')
            ->where('support_impersonation_sessions.expires_at', '>', now())
            ->where('support_impersonation_sessions.token_hash', hash('sha256', $token))
            ->select([
                'support_impersonation_sessions.*',
                'support_access_requests.ticket_id',
            ])
            ->first();
    }

    public function recordBlockedAction(object $session, string $action, ?AdminSessionContext $actor, Request $request): void
    {
        $blockedId = 'sib_'.Str::ulid()->toBase32();
        $now = now();

        SupportImpersonationBlockedAction::query()->insert([
            'id' => $blockedId,
            'tenant_id' => (string) $session->tenant_id,
            'support_access_request_id' => (string) $session->support_access_request_id,
            'support_impersonation_session_id' => (string) $session->id,
            'action' => $action,
            'status' => 'blocked',
            'actor_admin_id' => $actor?->adminUser['id'],
            'route' => $request->method().' /'.$request->path(),
            'reason' => 'Sensitive action is blocked during support impersonation.',
            'metadata_json' => json_encode([
                'request_id' => $request->header('X-Request-Id'),
                'token_last_four' => $session->token_last_four,
            ], JSON_THROW_ON_ERROR),
            'created_at' => $now,
            'updated_at' => $now,
        ]);

        SupportImpersonationEvent::query()->insert([
            'id' => 'sie_'.Str::ulid()->toBase32(),
            'tenant_id' => (string) $session->tenant_id,
            'support_access_request_id' => (string) $session->support_access_request_id,
            'support_impersonation_session_id' => (string) $session->id,
            'event_type' => 'support_impersonation.action_blocked',
            'action' => $action,
            'actor_admin_id' => $actor?->adminUser['id'],
            'target_user_id' => (string) $session->target_user_id,
            'target_user_type' => (string) $session->target_user_type,
            'reason' => 'Sensitive action is blocked during support impersonation.',
            'metadata_json' => json_encode(['route' => $request->method().' /'.$request->path()], JSON_THROW_ON_ERROR),
            'created_at' => $now,
            'updated_at' => $now,
        ]);

        $this->insertOutboxBlocked($session, $action, $actor, $request);
        $tenant = PartnerTenant::find($session->tenant_id);
        $this->auditSupportAccess(
            $actor,
            $request,
            'support_impersonation.action_blocked',
            'support_impersonation_blocked_action',
            $blockedId,
            $tenant,
            [
                'support_access_request_id' => $session->support_access_request_id,
                'session_id' => $session->id,
                'blocked_action' => $action,
                'route' => $request->method().' /'.$request->path(),
            ],
        );
    }

    /**
     * @param array<string, mixed>|null $issuedSession
     * @return array<string, mixed>
     */
    private function requestResource(object $request, bool $includeTrail = false, ?array $issuedSession = null): array
    {
        $resource = [
            'id' => (string) $request->id,
            'tenant_id' => (string) $request->tenant_id,
            'status' => (string) $request->status,
            'target_user_id' => (string) $request->target_user_id,
            'target_user_type' => (string) $request->target_user_type,
            'scope' => (string) $request->scope,
            'reason' => (string) $request->reason,
            'ticket_id' => (string) $request->ticket_id,
            'requested_by_admin_id' => (string) $request->requested_by_admin_id,
            'approved_by_admin_id' => $request->approved_by_admin_id,
            'approved_at' => $this->dateString($request->approved_at),
            'revoked_by_admin_id' => $request->revoked_by_admin_id,
            'revoked_at' => $this->dateString($request->revoked_at),
            'completed_at' => $this->dateString($request->completed_at),
            'expires_at' => $this->dateString($request->expires_at),
            'created_at' => $this->dateString($request->created_at),
            'updated_at' => $this->dateString($request->updated_at),
        ];

        $activeSession = SupportImpersonationSession::query()
            ->where('support_access_request_id', $request->id)
            ->orderByDesc('created_at')
            ->first();

        if ($issuedSession !== null) {
            $resource['active_session'] = $issuedSession;
        } elseif ($activeSession !== null) {
            $resource['active_session'] = $this->sessionResource($activeSession);
        }

        if ($includeTrail) {
            $resource['approvals'] = SupportAccessApproval::query()
                ->where('support_access_request_id', $request->id)
                ->orderBy('id')
                ->get()
                ->map(fn (object $approval): array => $this->approvalResource($approval))
                ->all();
            $resource['events'] = SupportImpersonationEvent::query()
                ->where('support_access_request_id', $request->id)
                ->orderBy('id')
                ->get()
                ->map(fn (object $event): array => $this->eventResource($event))
                ->all();
        }

        return $resource;
    }

    /**
     * @return array<string, mixed>
     */
    private function sessionResource(object $session, ?string $initialToken = null): array
    {
        $resource = [
            'id' => (string) $session->id,
            'support_access_request_id' => (string) $session->support_access_request_id,
            'target_user_id' => (string) $session->target_user_id,
            'target_user_type' => (string) $session->target_user_type,
            'scope' => (string) $session->scope,
            'status' => (string) $session->status,
            'token_last_four' => (string) $session->token_last_four,
            'started_at' => $this->dateString($session->started_at),
            'expires_at' => $this->dateString($session->expires_at),
            'revoked_at' => $this->dateString($session->revoked_at),
            'ended_at' => $this->dateString($session->ended_at),
        ];

        if ($initialToken !== null) {
            $resource['access_token'] = $initialToken;
        }

        return $resource;
    }

    /**
     * @return array<string, mixed>
     */
    private function approvalResource(object $approval): array
    {
        return [
            'id' => (string) $approval->id,
            'action' => (string) $approval->action,
            'status' => (string) $approval->status,
            'reason' => (string) $approval->reason,
            'actor_admin_id' => (string) $approval->actor_admin_id,
            'created_at' => $this->dateString($approval->created_at),
        ];
    }

    /**
     * @return array<string, mixed>
     */
    private function eventResource(object $event): array
    {
        return [
            'id' => (string) $event->id,
            'event_type' => (string) $event->event_type,
            'action' => $event->action,
            'actor_admin_id' => $event->actor_admin_id,
            'target_user_id' => $event->target_user_id,
            'target_user_type' => $event->target_user_type,
            'reason' => $event->reason,
            'metadata' => $this->decodeJsonObject($event->metadata_json),
            'created_at' => $this->dateString($event->created_at),
        ];
    }

    /**
     * @param array<string, mixed> $payload
     */
    private function insertApprovalEvent(
        string $tenantId,
        string $supportAccessId,
        string $action,
        string $status,
        string $reason,
        AdminSessionContext $actor,
        array $payload,
    ): void {
        SupportAccessApproval::query()->insert([
            'id' => 'saa_'.Str::ulid()->toBase32(),
            'tenant_id' => $tenantId,
            'support_access_request_id' => $supportAccessId,
            'action' => $action,
            'status' => $status,
            'reason' => $reason,
            'actor_admin_id' => $actor->adminUser['id'],
            'metadata_json' => json_encode($payload, JSON_THROW_ON_ERROR),
            'created_at' => now(),
            'updated_at' => now(),
        ]);
    }

    /**
     * @param array<string, mixed> $payload
     */
    private function insertImpersonationEvent(
        string $tenantId,
        string $supportAccessId,
        ?string $sessionId,
        string $eventType,
        ?string $action,
        AdminSessionContext $actor,
        array $payload,
    ): void {
        $request = SupportAccessRequest::find($supportAccessId);

        SupportImpersonationEvent::query()->insert([
            'id' => 'sie_'.Str::ulid()->toBase32(),
            'tenant_id' => $tenantId,
            'support_access_request_id' => $supportAccessId,
            'support_impersonation_session_id' => $sessionId,
            'event_type' => $eventType,
            'action' => $action,
            'actor_admin_id' => $actor->adminUser['id'],
            'target_user_id' => $request->target_user_id ?? null,
            'target_user_type' => $request->target_user_type ?? null,
            'reason' => $payload['reason'] ?? null,
            'metadata_json' => json_encode($payload, JSON_THROW_ON_ERROR),
            'created_at' => now(),
            'updated_at' => now(),
        ]);
    }

    private function insertOutboxStarted(object $request, string $sessionId, AdminSessionContext $actor, Request $httpRequest, mixed $expiresAt): void
    {
        $this->insertOutboxEvent(
            eventType: 'support_impersonation.started.v1',
            tenantId: (string) $request->tenant_id,
            aggregateType: 'support_impersonation_session',
            aggregateId: $sessionId,
            idempotencyKey: $httpRequest->header('Idempotency-Key'),
            correlationId: $httpRequest->header('X-Request-Id'),
            payload: [
                'session_id' => $sessionId,
                'tenant_id' => (string) $request->tenant_id,
                'actor_admin_id' => $actor->adminUser['id'],
                'target_user_id' => (string) $request->target_user_id,
                'target_user_type' => (string) $request->target_user_type,
                'scope' => (string) $request->scope,
                'ticket_id' => (string) $request->ticket_id,
                'expires_at' => (string) $expiresAt,
            ],
        );
    }

    private function insertOutboxBlocked(object $session, string $action, ?AdminSessionContext $actor, Request $request): void
    {
        $this->insertOutboxEvent(
            eventType: 'support_impersonation.action_blocked.v1',
            tenantId: (string) $session->tenant_id,
            aggregateType: 'support_impersonation_blocked_action',
            aggregateId: (string) $session->id,
            idempotencyKey: $request->header('Idempotency-Key'),
            correlationId: $request->header('X-Request-Id'),
            payload: [
                'session_id' => (string) $session->id,
                'tenant_id' => (string) $session->tenant_id,
                'actor_admin_id' => $actor?->adminUser['id'],
                'target_user_id' => (string) $session->target_user_id,
                'blocked_action' => $action,
                'route' => $request->method().' /'.$request->path(),
            ],
        );
    }

    /**
     * @param array<string, mixed> $payload
     */
    private function insertOutboxEvent(
        string $eventType,
        string $tenantId,
        string $aggregateType,
        string $aggregateId,
        ?string $idempotencyKey,
        ?string $correlationId,
        array $payload,
    ): void {
        $tenant = PartnerTenant::find($tenantId);
        $eventId = 'evt_'.Str::ulid()->toBase32();
        $now = now();

        SyncOutbox::query()->insert([
            'id' => $eventId,
            'event_id' => $eventId,
            'event_type' => $eventType,
            'event_version' => 1,
            'producer' => 'support_access',
            'tenant_id' => $tenantId,
            'partner_id' => $tenant->partner_id ?? null,
            'game_id' => null,
            'aggregate_type' => $aggregateType,
            'aggregate_id' => $aggregateId,
            'idempotency_key' => $idempotencyKey,
            'correlation_id' => $correlationId,
            'payload_json' => json_encode($payload, JSON_THROW_ON_ERROR),
            'status' => 'pending',
            'attempt_count' => 0,
            'available_at' => $now,
            'processed_at' => null,
            'last_error' => null,
            'created_at' => $now,
            'updated_at' => $now,
        ]);
    }

    /**
     * @param array<string, mixed> $payload
     */
    private function auditSupportAccess(
        ?AdminSessionContext $actor,
        Request $request,
        string $action,
        string $targetType,
        ?string $targetId,
        ?object $tenant,
        array $payload,
    ): void {
        if (! $actor instanceof AdminSessionContext) {
            return;
        }

        $this->auditLogger->logAdminWrite(
            actorId: $actor->adminUser['id'],
            scopeType: 'tenant',
            action: $action,
            targetType: $targetType,
            targetId: $targetId,
            payload: $payload,
            tenantId: $tenant->id ?? null,
            partnerId: $tenant->partner_id ?? null,
            requestId: $request->header('X-Request-Id'),
            ipAddress: $request->ip(),
            userAgent: $request->userAgent(),
        );
    }

    private function expireRequests(string $tenantId): void
    {
        SupportAccessRequest::query()
            ->where('tenant_id', $tenantId)
            ->whereIn('status', ['pending_approval', 'approved'])
            ->whereNotNull('expires_at')
            ->where('expires_at', '<=', now())
            ->update([
                'status' => 'expired',
                'updated_at' => now(),
            ]);

        SupportImpersonationSession::query()
            ->where('tenant_id', $tenantId)
            ->where('status', 'active')
            ->where('expires_at', '<=', now())
            ->update([
                'status' => 'expired',
                'updated_at' => now(),
            ]);
    }

    /**
     * @return array<string, mixed>
     */
    private function decodeJsonObject(mixed $json): array
    {
        if (is_array($json)) {
            return $json;
        }

        if ($json === null || $json === '') {
            return [];
        }

        $decoded = json_decode((string) $json, true);

        return is_array($decoded) ? $decoded : [];
    }

    private function dateString(mixed $value): ?string
    {
        return $value === null ? null : (string) $value;
    }

    private function limit(mixed $value): int
    {
        $limit = filter_var($value, FILTER_VALIDATE_INT);

        return $limit === false ? 50 : max(1, min(100, $limit));
    }
}
