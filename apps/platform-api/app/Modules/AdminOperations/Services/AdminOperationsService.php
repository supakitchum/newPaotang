<?php

namespace App\Modules\AdminOperations\Services;

use App\Models\AdminMenu;
use App\Models\AdminUser;
use App\Models\AdminUserRole;
use App\Models\AuditLog;
use App\Models\Partner;
use App\Models\PartnerTenant;
use App\Models\Role;
use App\Shared\Audit\AuditLogger;
use App\Shared\Auth\AdminSessionContext;
use Illuminate\Support\Facades\DB;

class AdminOperationsService
{
    public function __construct(private readonly AuditLogger $auditLogger)
    {
    }

    /**
     * @return array<string, mixed>
     */
    public function dashboardSummary(string $scopeType, ?string $tenantId): array
    {
        $summary = [
            'scope' => $scopeType,
            'tenant_id' => $scopeType === 'tenant' ? $tenantId : null,
            'generated_at' => now()->toISOString(),
            'kpis' => $scopeType === 'tenant'
                ? $this->tenantDashboardKpis($tenantId)
                : $this->centralDashboardKpis(),
            'charts' => [
                'activity' => [
                    'labels' => [],
                    'series' => [],
                ],
            ],
            'alerts' => [],
        ];

        return $summary;
    }

    /**
     * @param array<string, mixed> $payload
     * @return array<string, array<int, string>>
     */
    public function realtimeValidationErrors(array $payload): array
    {
        $errors = [];

        foreach (['socket_id', 'channel_name'] as $field) {
            if (! array_key_exists($field, $payload) || ! is_string($payload[$field]) || trim($payload[$field]) === '') {
                $errors[$field][] = 'The '.$field.' field is required.';
            }
        }

        if (array_key_exists('socket_id', $payload) && is_string($payload['socket_id']) && strlen($payload['socket_id']) > 120) {
            $errors['socket_id'][] = 'The socket_id field must not exceed 120 characters.';
        }

        if (array_key_exists('channel_name', $payload) && is_string($payload['channel_name']) && strlen($payload['channel_name']) > 200) {
            $errors['channel_name'][] = 'The channel_name field must not exceed 200 characters.';
        }

        return $errors;
    }

    /**
     * @param array<string, mixed> $payload
     * @return array<string, mixed>|null
     */
    public function realtimeAuth(AdminSessionContext $context, string $scopeType, array $payload): ?array
    {
        $socketId = trim((string) $payload['socket_id']);
        $channelName = trim((string) $payload['channel_name']);

        if (! $this->isAllowedAdminChannel($context, $scopeType, $channelName)) {
            return null;
        }

        $channelData = null;
        $stringToSign = $socketId.':'.$channelName;

        if (str_starts_with($channelName, 'presence-')) {
            $channelData = json_encode([
                'user_id' => $context->adminUser['id'],
                'user_info' => [
                    'name' => $context->adminUser['name'],
                    'scope' => $scopeType,
                    'tenant_id' => $context->activeTenantId(),
                ],
            ], JSON_THROW_ON_ERROR);

            $stringToSign .= ':'.$channelData;
        }

        $key = (string) config('platform.realtime.admin_key', 'newpaotang-admin');
        $secret = (string) config('platform.realtime.admin_secret', 'newpaotang-admin-secret');

        if ($key === '') {
            $key = 'newpaotang-admin';
        }

        if ($secret === '') {
            $secret = 'newpaotang-admin-secret';
        }

        return [
            'auth' => $key.':'.hash_hmac('sha256', $stringToSign, $secret),
            'channel_data' => $channelData,
            'expires_at' => now()->addSeconds((int) config('platform.realtime.auth_ttl_seconds', 300))->toISOString(),
        ];
    }

    public function requiredRealtimePermission(string $scopeType, string $channelName): ?string
    {
        if ($scopeType !== 'central') {
            return null;
        }

        if ($this->isCentralStockGenerationChannel($channelName)) {
            return 'stock.generate';
        }

        if ($this->isCentralStockTableChannel($channelName)) {
            return 'stock.view';
        }

        return null;
    }

    /**
     * @param array<string, mixed> $queryParams
     * @return array{data: array<int, array<string, mixed>>, meta: array<string, mixed>}
     */
    public function auditLogs(string $scopeType, ?string $tenantId, array $queryParams): array
    {
        $limit = $this->limit($queryParams['limit'] ?? null);
        $query = AuditLog::query()
            ->where('scope_type', $scopeType)
            ->orderByDesc('created_at')
            ->orderByDesc('id');

        if ($scopeType === 'tenant') {
            $query->where('tenant_id', $tenantId);
        } else {
            $query->whereNull('tenant_id');
        }

        if (($queryParams['action'] ?? null) !== null && trim((string) $queryParams['action']) !== '') {
            $query->where('action', trim((string) $queryParams['action']));
        }

        if (($queryParams['actor_id'] ?? null) !== null && trim((string) $queryParams['actor_id']) !== '') {
            $query->where('actor_id', trim((string) $queryParams['actor_id']));
        }

        $cursor = $this->decodeCursor($queryParams['cursor'] ?? null);

        if ($cursor !== null) {
            $query->where(function ($nested) use ($cursor): void {
                $nested->where('created_at', '<', $cursor['created_at'])
                    ->orWhere(function ($sameCreatedAt) use ($cursor): void {
                        $sameCreatedAt->where('created_at', '=', $cursor['created_at'])
                            ->where('id', '<', $cursor['id']);
                    });
            });
        }

        $rows = $query->limit($limit + 1)->get()->all();
        $hasMore = count($rows) > $limit;
        $rows = array_slice($rows, 0, $limit);

        return [
            'data' => array_map(fn (object $row): array => $this->auditLogResource($row), $rows),
            'meta' => [
                'next_cursor' => $hasMore && $rows !== [] ? $this->encodeCursor($rows[array_key_last($rows)]) : null,
                'has_more' => $hasMore,
            ],
        ];
    }

    /**
     * @return array<string, int>
     */
    private function centralDashboardKpis(): array
    {
        return [
            'partners_total' => Partner::count(),
            'partners_active' => Partner::where('status', 'active')->count(),
            'tenants_total' => PartnerTenant::count(),
            'tenants_active' => PartnerTenant::where('status', 'active')->count(),
            'admin_users_total' => AdminUser::count(),
            'roles_total' => Role::where('scope_type', 'central')->whereNull('tenant_id')->count(),
            'menus_total' => AdminMenu::where('scope_type', 'central')->count(),
            'audit_logs_total' => AuditLog::where('scope_type', 'central')->whereNull('tenant_id')->count(),
        ];
    }

    /**
     * @return array<string, int>
     */
    private function tenantDashboardKpis(?string $tenantId): array
    {
        return [
            'admin_users_total' => AdminUserRole::query()
                ->join('admin_scopes', 'admin_scopes.id', '=', 'admin_user_roles.scope_id')
                ->where('admin_scopes.scope_type', 'tenant')
                ->where('admin_scopes.tenant_id', $tenantId)
                ->distinct('admin_user_roles.admin_user_id')
                ->count('admin_user_roles.admin_user_id'),
            'roles_total' => Role::where('scope_type', 'tenant')
                ->where('tenant_id', $tenantId)
                ->count(),
            'menus_total' => AdminMenu::where('scope_type', 'tenant')->count(),
            'audit_logs_total' => AuditLog::where('scope_type', 'tenant')
                ->where('tenant_id', $tenantId)
                ->count(),
            'orders_total' => 0,
            'tickets_total' => 0,
            'topups_total' => 0,
        ];
    }

    private function isAllowedAdminChannel(AdminSessionContext $context, string $scopeType, string $channelName): bool
    {
        $adminUserId = $context->adminUser['id'];

        if ($scopeType === 'central') {
            return in_array($channelName, [
                'private-admin.central',
                'presence-admin.central',
                'private-admin.central.dashboard',
                'private-admin.central.audit',
                'private-admin.central.menu',
                'private-admin.central.admin.'.$adminUserId,
                'presence-admin.central.admin.'.$adminUserId,
            ], true) || $this->isCentralStockGenerationChannel($channelName)
                || $this->isCentralStockCoverageChannel($channelName)
                || $this->isCentralStockTableChannel($channelName);
        }

        $tenantId = $context->activeTenantId();

        if ($tenantId === null || $tenantId === '') {
            return false;
        }

        return in_array($channelName, [
            'private-admin.tenant.'.$tenantId,
            'presence-admin.tenant.'.$tenantId,
            'private-admin.tenant.'.$tenantId.'.dashboard',
            'private-admin.tenant.'.$tenantId.'.audit',
            'private-admin.tenant.'.$tenantId.'.menu',
            'private-admin.tenant.'.$tenantId.'.admin.'.$adminUserId,
            'presence-admin.tenant.'.$tenantId.'.admin.'.$adminUserId,
        ], true);
    }

    private function isCentralStockGenerationChannel(string $channelName): bool
    {
        return $channelName === 'private-admin.central.stock-generation'
            || preg_match('/^private-admin\.central\.stock-generation\.game\.[A-Za-z0-9_-]+$/', $channelName) === 1
            || preg_match('/^private-admin\.central\.stock-generation\.batch\.[A-Za-z0-9_-]+$/', $channelName) === 1;
    }

    private function isCentralStockCoverageChannel(string $channelName): bool
    {
        return preg_match('/^private-admin\.central\.stock\.coverage\.game\.[A-Za-z0-9_-]+$/', $channelName) === 1;
    }

    private function isCentralStockTableChannel(string $channelName): bool
    {
        return preg_match('/^private-admin\.central\.stock\.table\.game\.[A-Za-z0-9_-]+$/', $channelName) === 1;
    }

    private function limit(mixed $value): int
    {
        $limit = filter_var($value, FILTER_VALIDATE_INT);

        if ($limit === false) {
            return 50;
        }

        return max(1, min(100, $limit));
    }

    /**
     * @return array{id: string, created_at: string}|null
     */
    private function decodeCursor(mixed $cursor): ?array
    {
        if (! is_string($cursor) || trim($cursor) === '') {
            return null;
        }

        $decoded = base64_decode($cursor, true);

        if ($decoded === false) {
            return null;
        }

        $payload = json_decode($decoded, true);

        if (! is_array($payload) || ! is_string($payload['id'] ?? null) || ! is_string($payload['created_at'] ?? null)) {
            return null;
        }

        return [
            'id' => $payload['id'],
            'created_at' => $payload['created_at'],
        ];
    }

    private function encodeCursor(object $row): string
    {
        return base64_encode(json_encode([
            'id' => (string) $row->id,
            'created_at' => (string) $row->created_at,
        ], JSON_THROW_ON_ERROR));
    }

    /**
     * @return array<string, mixed>
     */
    private function auditLogResource(object $row): array
    {
        $payload = [];

        if ($row->payload_redacted_json !== null) {
            $decoded = is_array($row->payload_redacted_json)
                ? $row->payload_redacted_json
                : json_decode((string) $row->payload_redacted_json, true);
            $payload = is_array($decoded) ? $this->auditLogger->redactPayload($decoded) : [];
        }

        return [
            'id' => (string) $row->id,
            'tenant_id' => $row->tenant_id,
            'status' => null,
            'created_at' => $row->created_at,
            'updated_at' => $row->updated_at,
            'scope' => (string) $row->scope_type,
            'actor_type' => (string) $row->actor_type,
            'actor_id' => (string) $row->actor_id,
            'partner_id' => $row->partner_id,
            'action' => (string) $row->action,
            'target_type' => $row->target_type,
            'target_id' => $row->target_id,
            'request_id' => $row->request_id,
            'payload' => $payload,
        ];
    }
}
