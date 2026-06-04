<?php

namespace App\Modules\Maintenance\Services;

use App\Models\Partner;
use App\Models\PartnerCentralMaintenanceSetting;
use App\Models\PartnerTenant;
use App\Models\PartnerTenantMaintenanceBypass;
use App\Models\PartnerTenantMaintenanceEvent;
use App\Models\PartnerTenantMaintenanceSetting;
use App\Models\PartnerTenantSetting;
use App\Models\SyncOutbox;
use App\Modules\Maintenance\Events\TenantSiteConfigUpdated;
use App\Shared\Audit\AuditLogger;
use App\Shared\Auth\AdminSessionContext;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Log;
use Illuminate\Support\Facades\Schema;
use Illuminate\Support\Str;

class MaintenanceService
{
    private const MODES = ['full_site', 'customer_web_only', 'admin_only', 'checkout_payment_only', 'read_only', 'scheduled'];

    public function __construct(private readonly AuditLogger $auditLogger)
    {
    }

    /**
     * @return array<string, mixed>|null
     */
    public function settingForTenant(string $tenantId): ?array
    {
        $tenant = PartnerTenant::find($tenantId);

        if ($tenant === null) {
            return null;
        }

        return $this->settingResource($this->ensureSetting($tenant), (string) $tenant->status);
    }

    /**
     * @return array<string, mixed>|null
     */
    public function settingForPartner(string $partnerId): ?array
    {
        $partner = Partner::find($partnerId);

        if ($partner === null) {
            return null;
        }

        if (! $this->partnerMaintenanceTableExists()) {
            return $this->defaultPartnerMaintenanceResource($partnerId, (string) $partner->status);
        }

        $setting = PartnerCentralMaintenanceSetting::query()->where('partner_id', $partnerId)->first();

        return $setting === null
            ? $this->defaultPartnerMaintenanceResource($partnerId, (string) $partner->status)
            : $this->partnerSettingResource($setting, (string) $partner->status);
    }

    /**
     * @param array<string, mixed> $queryParams
     * @return array{data: array<int, array<string, mixed>>, meta: array<string, mixed>}
     */
    public function centralTenantMaintenanceList(array $queryParams): array
    {
        $limit = $this->limit($queryParams['limit'] ?? null);
        $query = PartnerTenant::query()
            ->join('partners', 'partners.id', '=', 'partner_tenants.partner_id')
            ->leftJoin('partner_tenant_domains', function ($join): void {
                $join->on('partner_tenant_domains.tenant_id', '=', 'partner_tenants.id')
                    ->where('partner_tenant_domains.is_primary', true);
            })
            ->select([
                'partner_tenants.id as tenant_id',
                'partner_tenants.code as tenant_code',
                'partner_tenants.name as tenant_name',
                'partner_tenants.status as tenant_status',
                'partner_tenants.updated_at as tenant_updated_at',
                'partners.id as partner_id',
                'partners.code as partner_code',
                'partners.name as partner_name',
                'partners.status as partner_status',
                'partner_tenant_domains.id as domain_id',
                'partner_tenant_domains.host as domain_host',
                'partner_tenant_domains.status as domain_status',
            ])
            ->orderBy('partners.code')
            ->orderBy('partner_tenants.code');

        $q = strtolower(trim((string) ($queryParams['q'] ?? '')));
        if ($q !== '') {
            $query->where(function ($nested) use ($q): void {
                $nested->whereRaw('LOWER(partners.code) like ?', ['%'.$q.'%'])
                    ->orWhereRaw('LOWER(partners.name) like ?', ['%'.$q.'%'])
                    ->orWhereRaw('LOWER(partner_tenants.code) like ?', ['%'.$q.'%'])
                    ->orWhereRaw('LOWER(partner_tenants.name) like ?', ['%'.$q.'%'])
                    ->orWhereRaw('LOWER(partner_tenant_domains.host) like ?', ['%'.$q.'%']);
            });
        }

        $status = strtolower(trim((string) ($queryParams['status'] ?? '')));
        if ($status !== '') {
            $query->where(function ($nested) use ($status): void {
                $nested->whereRaw('LOWER(partners.status) = ?', [$status])
                    ->orWhereRaw('LOWER(partner_tenants.status) = ?', [$status]);
            });
        }

        $rows = $query->limit($limit)->get()->all();

        return [
            'data' => array_map(fn (object $row): array => $this->centralTenantMaintenanceResource($row), $rows),
            'meta' => [
                'next_cursor' => null,
                'has_more' => false,
            ],
        ];
    }

    /**
     * @return array<string, mixed>
     */
    public function stateForTenant(string $tenantId, string $tenantStatus = 'active'): array
    {
        $setting = PartnerTenantMaintenanceSetting::query()->forTenant($tenantId)->first();

        if ($setting !== null) {
            return $this->settingResource($setting, $tenantStatus);
        }

        $legacy = PartnerTenantSetting::query()->forTenant($tenantId)->first();

        if ($legacy !== null) {
            $active = (bool) $legacy->maintenance_active || $tenantStatus === 'maintenance';

            return [
                'id' => null,
                'tenant_id' => $tenantId,
                'status' => $active ? 'active' : 'inactive',
                'active' => $active,
                'mode' => $this->validMode($legacy->maintenance_mode) ? (string) $legacy->maintenance_mode : 'scheduled',
                'message' => $legacy->maintenance_message,
                'reason' => null,
                'reason_label' => null,
                'ticket_id' => null,
                'ticket_public_ref' => null,
                'scheduled_start_at' => null,
                'started_at' => null,
                'expected_end_at' => $legacy->maintenance_expected_end_at,
                'ended_at' => null,
                'retry_after_seconds' => $legacy->maintenance_retry_after_seconds === null ? null : (int) $legacy->maintenance_retry_after_seconds,
                'allowed_routes' => $this->decodeJsonList($legacy->maintenance_allowed_routes_json),
                'blocked_route_patterns' => $this->decodeJsonList($legacy->maintenance_blocked_route_patterns_json),
                'created_at' => $legacy->created_at,
                'updated_at' => $legacy->updated_at,
            ];
        }

        $active = $tenantStatus === 'maintenance';

        return [
            'id' => null,
            'tenant_id' => $tenantId,
            'status' => $active ? 'active' : 'inactive',
            'active' => $active,
            'mode' => 'scheduled',
            'message' => null,
            'reason' => null,
            'reason_label' => null,
            'ticket_id' => null,
            'ticket_public_ref' => null,
            'scheduled_start_at' => null,
            'started_at' => null,
            'expected_end_at' => null,
            'ended_at' => null,
            'retry_after_seconds' => null,
            'allowed_routes' => [],
            'blocked_route_patterns' => [],
            'created_at' => null,
            'updated_at' => null,
        ];
    }

    /**
     * @return array<string, mixed>
     */
    public function stateForPartner(string $partnerId, string $partnerStatus = 'active'): array
    {
        if (! $this->partnerMaintenanceTableExists()) {
            return $this->defaultPartnerMaintenanceResource($partnerId, $partnerStatus);
        }

        $setting = PartnerCentralMaintenanceSetting::query()->where('partner_id', $partnerId)->first();

        return $setting === null
            ? $this->defaultPartnerMaintenanceResource($partnerId, $partnerStatus)
            : $this->partnerSettingResource($setting, $partnerStatus);
    }

    public function partnerBoIsBlockedByCentralMaintenance(string $partnerId): bool
    {
        return (bool) ($this->stateForPartner($partnerId)['active'] ?? false);
    }

    public function shouldBlock(array $state, string $operation, ?string $path = null): bool
    {
        if (! (bool) ($state['active'] ?? false)) {
            return false;
        }

        $pathCandidates = $this->maintenancePathCandidates($path);
        if ($pathCandidates !== [] && $this->matchesAnyMaintenancePattern($pathCandidates, $state['blocked_route_patterns'] ?? [])) {
            return true;
        }

        if ($pathCandidates !== [] && $this->matchesAnyMaintenancePattern($pathCandidates, $state['allowed_routes'] ?? [])) {
            return false;
        }

        $mode = (string) ($state['mode'] ?? 'scheduled');

        return match ($mode) {
            'full_site' => in_array($operation, ['public_read', 'customer_read', 'customer_write', 'reservation_write', 'checkout_payment', 'payment_write', 'profile_write'], true),
            'customer_web_only' => in_array($operation, ['public_read', 'customer_read', 'customer_write', 'reservation_write', 'checkout_payment', 'payment_write', 'profile_write'], true),
            'checkout_payment_only' => in_array($operation, ['reservation_write', 'checkout_payment', 'payment_write'], true),
            'read_only' => in_array($operation, ['customer_write', 'reservation_write', 'checkout_payment', 'payment_write', 'profile_write', 'admin_write'], true),
            'admin_only' => $operation === 'admin_write',
            default => false,
        };
    }

    /**
     * @param array<string, mixed> $payload
     * @return array<string, mixed>|null
     */
    public function updateSetting(string $tenantId, array $payload, AdminSessionContext $actor, Request $request): ?array
    {
        return DB::transaction(function () use ($tenantId, $payload, $actor, $request): ?array {
            $tenant = PartnerTenant::query()->where('id', $tenantId)->lockForUpdate()->first();

            if ($tenant === null) {
                return null;
            }

            $previous = $this->ensureSetting($tenant);
            $now = now();
            $status = (string) $payload['status'];
            $mode = (string) $payload['mode'];
            $active = $status === 'active';
            $settingId = (string) $previous->id;

            $updates = [
                'status' => $status,
                'mode' => $mode,
                'message' => $payload['message'] ?? null,
                'reason' => (string) $payload['reason'],
                'ticket_id' => $payload['ticket_id'] ?? null,
                'scheduled_start_at' => $this->dateOrNull($payload['scheduled_start_at'] ?? null),
                'expected_end_at' => $this->dateOrNull($payload['expected_end_at'] ?? null),
                'retry_after_seconds' => $payload['retry_after_seconds'] ?? null,
                'allowed_routes_json' => json_encode($this->normalizedStringList($payload['allowed_routes'] ?? []), JSON_THROW_ON_ERROR),
                'blocked_route_patterns_json' => json_encode($this->normalizedStringList($payload['blocked_route_patterns'] ?? []), JSON_THROW_ON_ERROR),
                'updated_by_admin_id' => $actor->adminUser['id'],
                'updated_at' => $now,
            ];

            if ($status === 'active' && $previous->started_at === null) {
                $updates['started_at'] = $now;
            }

            if (in_array($status, ['inactive', 'ended', 'cancelled'], true)) {
                $updates['ended_at'] = $now;
            }

            PartnerTenantMaintenanceSetting::query()->where('id', $settingId)->update($updates);

            $tenantStatus = (string) $tenant->status;
            if ($status === 'active' && $tenantStatus === 'active') {
                PartnerTenant::query()->where('id', $tenantId)->update([
                    'status' => 'maintenance',
                    'updated_at' => $now,
                ]);
                $tenantStatus = 'maintenance';
            } elseif (in_array($status, ['inactive', 'ended', 'cancelled'], true) && $tenantStatus === 'maintenance') {
                PartnerTenant::query()->where('id', $tenantId)->update([
                    'status' => 'active',
                    'updated_at' => $now,
                ]);
                $tenantStatus = 'active';
            }

            $current = PartnerTenantMaintenanceSetting::where('id', $settingId)->first();
            $resource = $this->settingResource($current, $tenantStatus);

            $this->syncLegacySettings($tenant, $resource);
            $this->insertMaintenanceEvent($tenantId, $settingId, 'maintenance.updated', $actor, $payload, $resource);
            $this->insertOutboxEvent($tenant, $settingId, $request, $resource, (string) $actor->adminUser['id']);
            $this->broadcastSiteConfigUpdated($tenant, $resource);
            $auditAction = $active
                ? 'maintenance.enabled'
                : ((string) $previous->status === 'active' ? 'maintenance.disabled' : 'maintenance.updated');

            $this->auditLogger->logAdminWrite(
                actorId: $actor->adminUser['id'],
                scopeType: 'tenant',
                action: $auditAction,
                targetType: 'partner_tenant_maintenance_setting',
                targetId: $settingId,
                payload: [
                    'idempotency_key' => $request->header('Idempotency-Key'),
                    'previous' => [
                        'status' => $previous->status,
                        'mode' => $previous->mode,
                    ],
                    'current' => [
                        'status' => $resource['status'],
                        'mode' => $resource['mode'],
                        'reason' => $resource['reason'],
                        'ticket_id' => $resource['ticket_id'],
                    ],
                ],
                tenantId: $tenantId,
                partnerId: (string) $tenant->partner_id,
                requestId: $request->header('X-Request-Id'),
                ipAddress: $request->ip(),
                userAgent: $request->userAgent(),
            );

            return $resource;
        });
    }

    /**
     * @param array<string, mixed> $payload
     * @return array<string, mixed>|null
     */
    public function updatePartnerSetting(string $partnerId, array $payload, AdminSessionContext $actor, Request $request): ?array
    {
        if (! $this->partnerMaintenanceTableExists()) {
            return null;
        }

        return DB::transaction(function () use ($partnerId, $payload, $actor, $request): ?array {
            $partner = Partner::query()->where('id', $partnerId)->lockForUpdate()->first();

            if ($partner === null) {
                return null;
            }

            $previous = $this->ensurePartnerSetting($partner);
            $now = now();
            $status = (string) $payload['status'];
            $settingId = (string) $previous->id;
            $updates = [
                'status' => $status,
                'message' => $payload['message'] ?? null,
                'reason' => (string) $payload['reason'],
                'ticket_id' => $payload['ticket_id'] ?? null,
                'scheduled_start_at' => $this->dateOrNull($payload['scheduled_start_at'] ?? null),
                'expected_end_at' => $this->dateOrNull($payload['expected_end_at'] ?? null),
                'retry_after_seconds' => $payload['retry_after_seconds'] ?? null,
                'updated_by_admin_id' => $actor->adminUser['id'],
                'updated_at' => $now,
            ];

            if ($status === 'active') {
                $updates['started_at'] = $now;
                $updates['ended_at'] = null;
            }

            if (in_array($status, ['inactive', 'ended', 'cancelled'], true)) {
                $updates['ended_at'] = $now;
            }

            PartnerCentralMaintenanceSetting::query()->where('id', $settingId)->update($updates);

            $current = PartnerCentralMaintenanceSetting::where('id', $settingId)->first();
            $resource = $this->partnerSettingResource($current, (string) $partner->status);
            $auditAction = $status === 'active'
                ? 'partner_maintenance.enabled'
                : ((string) $previous->status === 'active' ? 'partner_maintenance.disabled' : 'partner_maintenance.updated');

            $this->auditLogger->logAdminWrite(
                actorId: $actor->adminUser['id'],
                scopeType: 'central',
                action: $auditAction,
                targetType: 'partner_central_maintenance_setting',
                targetId: $settingId,
                payload: [
                    'idempotency_key' => $request->header('Idempotency-Key'),
                    'previous' => [
                        'status' => $previous->status,
                    ],
                    'current' => [
                        'status' => $resource['status'],
                        'reason' => $resource['reason'],
                        'ticket_id' => $resource['ticket_id'],
                    ],
                ],
                tenantId: null,
                partnerId: (string) $partner->id,
                requestId: $request->header('X-Request-Id'),
                ipAddress: $request->ip(),
                userAgent: $request->userAgent(),
            );

            return $resource;
        });
    }

    /**
     * @param array<string, mixed> $queryParams
     * @return array{data: array<int, array<string, mixed>>, meta: array<string, mixed>}
     */
    public function eventsForTenant(string $tenantId, array $queryParams): array
    {
        $limit = $this->limit($queryParams['limit'] ?? null);
        $query = PartnerTenantMaintenanceEvent::query()
            ->forTenant($tenantId)
            ->orderBy('id')
            ->limit($limit + 1);

        if (($queryParams['cursor'] ?? null) !== null && trim((string) $queryParams['cursor']) !== '') {
            $query->where('id', '>', trim((string) $queryParams['cursor']));
        }

        $rows = $query->get()->all();
        $hasMore = count($rows) > $limit;
        $rows = array_slice($rows, 0, $limit);

        return [
            'data' => array_map(fn (object $row): array => $this->eventResource($row), $rows),
            'meta' => [
                'next_cursor' => $hasMore && $rows !== [] ? (string) end($rows)->id : null,
                'has_more' => $hasMore,
            ],
        ];
    }

    /**
     * @param array<string, mixed> $queryParams
     * @return array{data: array<int, array<string, mixed>>, meta: array<string, mixed>}
     */
    public function bypassesForTenant(string $tenantId, array $queryParams): array
    {
        $limit = $this->limit($queryParams['limit'] ?? null);
        $query = PartnerTenantMaintenanceBypass::query()
            ->forTenant($tenantId)
            ->orderBy('id')
            ->limit($limit + 1);

        $status = trim((string) ($queryParams['status'] ?? ''));

        if ($status === 'active') {
            $query->where('status', 'active')
                ->where(function ($builder): void {
                    $builder->whereNull('expires_at')->orWhere('expires_at', '>', now());
                });
        } elseif ($status === 'expired') {
            $query->where('status', 'active')->where('expires_at', '<=', now());
        } elseif ($status === 'revoked') {
            $query->where('status', 'revoked');
        }

        if (($queryParams['cursor'] ?? null) !== null && trim((string) $queryParams['cursor']) !== '') {
            $query->where('id', '>', trim((string) $queryParams['cursor']));
        }

        $rows = $query->get()->all();
        $hasMore = count($rows) > $limit;
        $rows = array_slice($rows, 0, $limit);

        return [
            'data' => array_map(fn (object $row): array => $this->bypassResource($row), $rows),
            'meta' => [
                'next_cursor' => $hasMore && $rows !== [] ? (string) end($rows)->id : null,
                'has_more' => $hasMore,
            ],
        ];
    }

    /**
     * @param array<string, mixed> $payload
     * @return array<string, mixed>|string
     */
    public function createBypass(string $tenantId, array $payload, AdminSessionContext $actor, Request $request): array|string
    {
        return DB::transaction(function () use ($tenantId, $payload, $actor, $request): array|string {
            $tenant = PartnerTenant::find($tenantId);

            if ($tenant === null) {
                return 'not_found';
            }

            $now = now();
            $bypassId = 'byp_'.Str::ulid()->toBase32();

            PartnerTenantMaintenanceBypass::query()->insert([
                'id' => $bypassId,
                'tenant_id' => $tenantId,
                'bypass_type' => 'actor',
                'actor_type' => (string) $payload['actor_type'],
                'actor_id' => (string) $payload['actor_id'],
                'support_impersonation_session_id' => $payload['support_impersonation_session_id'] ?? null,
                'status' => 'active',
                'reason' => (string) $payload['reason'],
                'ticket_id' => $payload['ticket_id'] ?? null,
                'expires_at' => $this->dateOrNull($payload['expires_at'] ?? null),
                'revoked_at' => null,
                'created_by_admin_id' => $actor->adminUser['id'],
                'revoked_by_admin_id' => null,
                'metadata_json' => json_encode(['request_id' => $request->header('X-Request-Id')], JSON_THROW_ON_ERROR),
                'created_at' => $now,
                'updated_at' => $now,
            ]);

            $this->auditLogger->logAdminWrite(
                actorId: $actor->adminUser['id'],
                scopeType: 'tenant',
                action: 'maintenance.bypass_created',
                targetType: 'partner_tenant_maintenance_bypass',
                targetId: $bypassId,
                payload: [
                    'idempotency_key' => $request->header('Idempotency-Key'),
                    'actor_type' => $payload['actor_type'],
                    'actor_id' => $payload['actor_id'],
                    'reason' => $payload['reason'],
                    'ticket_id' => $payload['ticket_id'] ?? null,
                ],
                tenantId: $tenantId,
                partnerId: (string) $tenant->partner_id,
                requestId: $request->header('X-Request-Id'),
                ipAddress: $request->ip(),
                userAgent: $request->userAgent(),
            );

            return $this->bypassResource(PartnerTenantMaintenanceBypass::find($bypassId));
        });
    }

    public function revokeBypass(string $tenantId, string $bypassId, AdminSessionContext $actor, Request $request): bool
    {
        return DB::transaction(function () use ($tenantId, $bypassId, $actor, $request): bool {
            $bypass = PartnerTenantMaintenanceBypass::query()
                ->where('tenant_id', $tenantId)
                ->where('id', $bypassId)
                ->lockForUpdate()
                ->first();

            if ($bypass === null) {
                return false;
            }

            if ($bypass->status !== 'revoked') {
                PartnerTenantMaintenanceBypass::query()->where('id', $bypassId)->update([
                    'status' => 'revoked',
                    'revoked_at' => now(),
                    'revoked_by_admin_id' => $actor->adminUser['id'],
                    'updated_at' => now(),
                ]);
            }

            $tenant = PartnerTenant::find($tenantId);
            $this->auditLogger->logAdminWrite(
                actorId: $actor->adminUser['id'],
                scopeType: 'tenant',
                action: 'maintenance.bypass_revoked',
                targetType: 'partner_tenant_maintenance_bypass',
                targetId: $bypassId,
                payload: ['idempotency_key' => $request->header('Idempotency-Key')],
                tenantId: $tenantId,
                partnerId: $tenant->partner_id ?? null,
                requestId: $request->header('X-Request-Id'),
                ipAddress: $request->ip(),
                userAgent: $request->userAgent(),
            );

            return true;
        });
    }

    /**
     * @param array<string, mixed> $state
     */
    private function syncLegacySettings(object $tenant, array $state): void
    {
        $settings = PartnerTenantSetting::query()->forTenant((string) $tenant->id)->first();
        $now = now();
        $payload = [
            'maintenance_active' => (bool) $state['active'],
            'maintenance_mode' => $state['mode'],
            'maintenance_message' => $state['message'],
            'maintenance_expected_end_at' => $state['expected_end_at'],
            'maintenance_retry_after_seconds' => $state['retry_after_seconds'],
            'maintenance_allowed_routes_json' => json_encode($state['allowed_routes'], JSON_THROW_ON_ERROR),
            'maintenance_blocked_route_patterns_json' => json_encode($state['blocked_route_patterns'], JSON_THROW_ON_ERROR),
            'updated_at' => $now,
        ];

        if ($settings !== null) {
            $payload['config_version'] = ((int) $settings->config_version) + 1;
            PartnerTenantSetting::query()->where('tenant_id', $tenant->id)->update($payload);

            return;
        }

        PartnerTenantSetting::query()->insert($payload + [
            'id' => $this->stableId('pts', (string) $tenant->id),
            'tenant_id' => (string) $tenant->id,
            'site_name' => (string) $tenant->name,
            'display_name' => null,
            'locale' => 'th-TH',
            'timezone' => 'Asia/Bangkok',
            'support_email' => null,
            'support_phone' => null,
            'default_title' => (string) $tenant->name,
            'title_template' => null,
            'default_description' => null,
            'default_keywords_json' => json_encode([], JSON_THROW_ON_ERROR),
            'robots_default' => 'index,follow',
            'sitemap_enabled' => true,
            'robots_enabled' => true,
            'api_base_url' => '/api/v1',
            'realtime_url' => null,
            'asset_cdn_base_url' => null,
            'config_version' => 1,
            'created_at' => $now,
        ]);
    }

    private function ensureSetting(object $tenant): object
    {
        $setting = PartnerTenantMaintenanceSetting::query()->forTenant((string) $tenant->id)->first();

        if ($setting !== null) {
            return $setting;
        }

        $legacy = PartnerTenantSetting::query()->forTenant((string) $tenant->id)->first();
        $now = now();
        $active = ((bool) ($legacy->maintenance_active ?? false)) || (string) $tenant->status === 'maintenance';
        $settingId = 'mnt_'.Str::ulid()->toBase32();

        PartnerTenantMaintenanceSetting::query()->create([
            'id' => $settingId,
            'tenant_id' => (string) $tenant->id,
            'status' => $active ? 'active' : 'inactive',
            'mode' => $this->validMode($legacy->maintenance_mode ?? null) ? (string) $legacy->maintenance_mode : 'scheduled',
            'message' => $legacy->maintenance_message ?? null,
            'reason' => null,
            'ticket_id' => null,
            'scheduled_start_at' => null,
            'started_at' => $active ? $now : null,
            'expected_end_at' => $legacy->maintenance_expected_end_at ?? null,
            'ended_at' => null,
            'retry_after_seconds' => $legacy->maintenance_retry_after_seconds ?? null,
            'allowed_routes_json' => $legacy->maintenance_allowed_routes_json ?? json_encode([], JSON_THROW_ON_ERROR),
            'blocked_route_patterns_json' => $legacy->maintenance_blocked_route_patterns_json ?? json_encode([], JSON_THROW_ON_ERROR),
            'created_by_admin_id' => null,
            'updated_by_admin_id' => null,
            'created_at' => $now,
            'updated_at' => $now,
        ]);

        return PartnerTenantMaintenanceSetting::find($settingId);
    }

    private function ensurePartnerSetting(object $partner): object
    {
        $setting = PartnerCentralMaintenanceSetting::query()->where('partner_id', (string) $partner->id)->first();

        if ($setting !== null) {
            return $setting;
        }

        $settingId = 'pcm_'.Str::ulid()->toBase32();
        $now = now();

        PartnerCentralMaintenanceSetting::query()->create([
            'id' => $settingId,
            'partner_id' => (string) $partner->id,
            'status' => 'inactive',
            'message' => null,
            'reason' => null,
            'ticket_id' => null,
            'scheduled_start_at' => null,
            'started_at' => null,
            'expected_end_at' => null,
            'ended_at' => null,
            'retry_after_seconds' => null,
            'created_by_admin_id' => null,
            'updated_by_admin_id' => null,
            'created_at' => $now,
            'updated_at' => $now,
        ]);

        return PartnerCentralMaintenanceSetting::find($settingId);
    }

    /**
     * @return array<string, mixed>
     */
    private function settingResource(object $setting, string $tenantStatus): array
    {
        $active = (string) $setting->status === 'active';

        return [
            'id' => (string) $setting->id,
            'tenant_id' => (string) $setting->tenant_id,
            'status' => (string) $setting->status,
            'active' => $active,
            'mode' => $this->validMode($setting->mode) ? (string) $setting->mode : 'scheduled',
            'message' => $setting->message,
            'reason' => $setting->reason,
            'reason_label' => $setting->reason,
            'ticket_id' => $setting->ticket_id,
            'ticket_public_ref' => $setting->ticket_id,
            'scheduled_start_at' => $this->dateString($setting->scheduled_start_at),
            'started_at' => $this->dateString($setting->started_at),
            'expected_end_at' => $this->dateString($setting->expected_end_at),
            'ended_at' => $this->dateString($setting->ended_at),
            'retry_after_seconds' => $setting->retry_after_seconds === null ? null : (int) $setting->retry_after_seconds,
            'allowed_routes' => $this->decodeJsonList($setting->allowed_routes_json),
            'blocked_route_patterns' => $this->decodeJsonList($setting->blocked_route_patterns_json),
            'created_at' => $this->dateString($setting->created_at),
            'updated_at' => $this->dateString($setting->updated_at),
        ];
    }

    /**
     * @return array<string, mixed>
     */
    private function defaultPartnerMaintenanceResource(string $partnerId, string $partnerStatus): array
    {
        return [
            'id' => null,
            'partner_id' => $partnerId,
            'partner_status' => $partnerStatus,
            'source' => 'central_partner',
            'scope' => 'partner_bo',
            'status' => 'inactive',
            'active' => false,
            'mode' => 'partner_bo_only',
            'message' => null,
            'reason' => null,
            'reason_label' => null,
            'ticket_id' => null,
            'ticket_public_ref' => null,
            'scheduled_start_at' => null,
            'started_at' => null,
            'expected_end_at' => null,
            'ended_at' => null,
            'retry_after_seconds' => null,
            'created_at' => null,
            'updated_at' => null,
        ];
    }

    /**
     * @return array<string, mixed>
     */
    private function partnerSettingResource(object $setting, string $partnerStatus): array
    {
        $active = (string) $setting->status === 'active';

        return [
            'id' => (string) $setting->id,
            'partner_id' => (string) $setting->partner_id,
            'partner_status' => $partnerStatus,
            'source' => 'central_partner',
            'scope' => 'partner_bo',
            'status' => (string) $setting->status,
            'active' => $active,
            'mode' => 'partner_bo_only',
            'message' => $setting->message,
            'reason' => $setting->reason,
            'reason_label' => $setting->reason,
            'ticket_id' => $setting->ticket_id,
            'ticket_public_ref' => $setting->ticket_id,
            'scheduled_start_at' => $this->dateString($setting->scheduled_start_at),
            'started_at' => $this->dateString($setting->started_at),
            'expected_end_at' => $this->dateString($setting->expected_end_at),
            'ended_at' => $this->dateString($setting->ended_at),
            'retry_after_seconds' => $setting->retry_after_seconds === null ? null : (int) $setting->retry_after_seconds,
            'created_at' => $this->dateString($setting->created_at),
            'updated_at' => $this->dateString($setting->updated_at),
        ];
    }

    /**
     * @return array<string, mixed>
     */
    private function eventResource(object $event): array
    {
        return [
            'id' => (string) $event->id,
            'tenant_id' => (string) $event->tenant_id,
            'maintenance_setting_id' => $event->maintenance_setting_id,
            'event_type' => (string) $event->event_type,
            'status' => $event->status,
            'mode' => $event->mode,
            'reason' => $event->reason,
            'ticket_id' => $event->ticket_id,
            'actor_admin_id' => $event->actor_admin_id,
            'payload' => $this->decodeJsonObject($event->payload_json),
            'created_at' => $this->dateString($event->created_at),
            'updated_at' => $this->dateString($event->updated_at),
        ];
    }

    /**
     * @return array<string, mixed>
     */
    private function bypassResource(object $bypass): array
    {
        $expiresAt = $bypass->expires_at;
        $isExpired = $expiresAt !== null && now()->greaterThanOrEqualTo($expiresAt);
        $isCurrentlyActive = (string) $bypass->status === 'active' && ! $isExpired;

        return [
            'id' => (string) $bypass->id,
            'tenant_id' => (string) $bypass->tenant_id,
            'actor_type' => (string) $bypass->actor_type,
            'actor_id' => (string) $bypass->actor_id,
            'support_impersonation_session_id' => $bypass->support_impersonation_session_id,
            'status' => (string) $bypass->status,
            'effective_status' => $isExpired && (string) $bypass->status === 'active' ? 'expired' : (string) $bypass->status,
            'is_currently_active' => $isCurrentlyActive,
            'reason' => $bypass->reason,
            'ticket_id' => $bypass->ticket_id,
            'expires_at' => $this->dateString($bypass->expires_at),
            'revoked_at' => $this->dateString($bypass->revoked_at),
            'created_at' => $this->dateString($bypass->created_at),
            'updated_at' => $this->dateString($bypass->updated_at),
        ];
    }

    /**
     * @return array<string, mixed>
     */
    private function centralTenantMaintenanceResource(object $row): array
    {
        $maintenance = $this->stateForTenant((string) $row->tenant_id, (string) $row->tenant_status);
        $partnerMaintenance = $this->stateForPartner((string) $row->partner_id, (string) $row->partner_status);

        return [
            'id' => (string) $row->tenant_id,
            'tenant_id' => (string) $row->tenant_id,
            'tenant_code' => (string) $row->tenant_code,
            'tenant_name' => (string) $row->tenant_name,
            'tenant_status' => (string) $row->tenant_status,
            'partner_id' => (string) $row->partner_id,
            'partner_code' => (string) $row->partner_code,
            'partner_name' => (string) $row->partner_name,
            'partner_status' => (string) $row->partner_status,
            'domain_id' => $row->domain_id ? (string) $row->domain_id : null,
            'domain_host' => $row->domain_host ? (string) $row->domain_host : null,
            'domain_status' => $row->domain_status ? (string) $row->domain_status : null,
            'maintenance' => $maintenance,
            'maintenance_status' => (string) ($maintenance['status'] ?? 'inactive'),
            'maintenance_active' => (bool) ($maintenance['active'] ?? false),
            'maintenance_mode' => $maintenance['mode'] ?? null,
            'maintenance_message' => $maintenance['message'] ?? null,
            'partner_maintenance' => $partnerMaintenance,
            'partner_maintenance_status' => (string) ($partnerMaintenance['status'] ?? 'inactive'),
            'partner_maintenance_active' => (bool) ($partnerMaintenance['active'] ?? false),
            'partner_maintenance_mode' => $partnerMaintenance['mode'] ?? null,
            'partner_maintenance_message' => $partnerMaintenance['message'] ?? null,
            'updated_at' => $this->dateString($row->tenant_updated_at),
        ];
    }

    /**
     * @param array<string, mixed> $payload
     * @param array<string, mixed> $resource
     */
    private function insertMaintenanceEvent(string $tenantId, string $settingId, string $eventType, AdminSessionContext $actor, array $payload, array $resource): void
    {
        PartnerTenantMaintenanceEvent::query()->insert([
            'id' => 'mev_'.Str::ulid()->toBase32(),
            'tenant_id' => $tenantId,
            'maintenance_setting_id' => $settingId,
            'event_type' => $eventType,
            'status' => $resource['status'],
            'mode' => $resource['mode'],
            'reason' => $payload['reason'] ?? null,
            'ticket_id' => $payload['ticket_id'] ?? null,
            'actor_admin_id' => $actor->adminUser['id'],
            'payload_json' => json_encode([
                'request' => $payload,
                'setting' => $resource,
            ], JSON_THROW_ON_ERROR),
            'created_at' => now(),
            'updated_at' => now(),
        ]);
    }

    /**
     * @param array<string, mixed> $resource
     */
    private function insertOutboxEvent(object $tenant, string $settingId, Request $request, array $resource, string $actorId): void
    {
        $eventId = 'evt_'.Str::ulid()->toBase32();
        $now = now();

        SyncOutbox::query()->insert([
            'id' => $eventId,
            'event_id' => $eventId,
            'event_type' => 'maintenance.changed.v1',
            'event_version' => 1,
            'producer' => 'maintenance',
            'tenant_id' => (string) $tenant->id,
            'partner_id' => (string) $tenant->partner_id,
            'game_id' => null,
            'aggregate_type' => 'partner_tenant_maintenance_setting',
            'aggregate_id' => $settingId,
            'idempotency_key' => $request->header('Idempotency-Key'),
            'correlation_id' => $request->header('X-Request-Id'),
            'payload_json' => json_encode([
                'tenant_id' => (string) $tenant->id,
                'mode' => $resource['mode'],
                'status' => $resource['status'],
                'message' => $resource['message'],
                'retry_after_seconds' => $resource['retry_after_seconds'],
                'changed_by_admin_id' => $actorId,
            ], JSON_THROW_ON_ERROR),
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
     * @return array<int, string>
     */
    private function decodeJsonList(mixed $json): array
    {
        if (is_array($json)) {
            return array_values(array_filter($json, fn (mixed $value): bool => is_string($value)));
        }

        if ($json === null || $json === '') {
            return [];
        }

        $decoded = json_decode((string) $json, true);

        return is_array($decoded) ? array_values(array_filter($decoded, fn (mixed $value): bool => is_string($value))) : [];
    }

    /**
     * @return array<int, string>
     */
    private function maintenancePathCandidates(?string $path): array
    {
        $normalized = $this->normalizeMaintenancePath($path);

        if ($normalized === null) {
            return [];
        }

        $candidates = [$normalized];

        foreach (['/api/v1/customer/', '/api/v1/public/'] as $prefix) {
            if (str_starts_with($normalized, $prefix)) {
                $candidates[] = '/'.substr($normalized, strlen($prefix));
            }
        }

        return array_values(array_unique(array_filter($candidates)));
    }

    /**
     * @param array<int, string> $paths
     * @param mixed $patterns
     */
    private function matchesAnyMaintenancePattern(array $paths, mixed $patterns): bool
    {
        $normalizedPatterns = $this->normalizedStringList(is_array($patterns) ? $patterns : []);

        foreach ($normalizedPatterns as $pattern) {
            $normalizedPattern = $this->normalizeMaintenancePath($pattern);

            if ($normalizedPattern === null) {
                continue;
            }

            foreach ($paths as $path) {
                if ($this->maintenancePathMatches($normalizedPattern, $path)) {
                    return true;
                }
            }
        }

        return false;
    }

    private function maintenancePathMatches(string $pattern, string $path): bool
    {
        if ($pattern === $path || Str::is($pattern, $path)) {
            return true;
        }

        if (str_ends_with($pattern, '/*') && rtrim(substr($pattern, 0, -2), '/') === rtrim($path, '/')) {
            return true;
        }

        return false;
    }

    private function normalizeMaintenancePath(?string $path): ?string
    {
        $value = trim((string) $path);

        if ($value === '') {
            return null;
        }

        $parsedPath = parse_url($value, PHP_URL_PATH);
        $value = is_string($parsedPath) && $parsedPath !== '' ? $parsedPath : $value;
        $value = '/'.ltrim($value, '/');

        return $value === '/' ? '/' : rtrim($value, '/');
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

    /**
     * @param array<int, mixed> $values
     * @return array<int, string>
     */
    private function normalizedStringList(array $values): array
    {
        return array_values(array_filter(array_map(
            fn (mixed $value): string => trim((string) $value),
            $values,
        ), fn (string $value): bool => $value !== ''));
    }

    private function validMode(mixed $mode): bool
    {
        return is_string($mode) && in_array($mode, self::MODES, true);
    }

    private function dateOrNull(mixed $value): mixed
    {
        return $value === null || trim((string) $value) === '' ? null : $value;
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

    private function stableId(string $prefix, string $seed): string
    {
        return $prefix.'_'.substr(sha1($prefix.':'.$seed), 0, 20);
    }

    private function partnerMaintenanceTableExists(): bool
    {
        return Schema::hasTable('partner_central_maintenance_settings');
    }

    /**
     * @param array<string, mixed> $maintenance
     */
    private function broadcastSiteConfigUpdated(object $tenant, array $maintenance): void
    {
        try {
            TenantSiteConfigUpdated::dispatch([
                'tenant_id' => (string) $tenant->id,
                'partner_id' => (string) $tenant->partner_id,
                'maintenance' => $maintenance,
                'updated_at' => now()->toISOString(),
            ]);
        } catch (\Throwable $exception) {
            Log::warning('Customer site-config realtime broadcast failed.', [
                'tenant_id' => (string) $tenant->id,
                'message' => $exception->getMessage(),
            ]);
        }
    }
}
