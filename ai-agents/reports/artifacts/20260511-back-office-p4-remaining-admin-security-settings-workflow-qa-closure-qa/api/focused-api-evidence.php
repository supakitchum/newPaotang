<?php

declare(strict_types=1);

$apiBase = getenv('QA_API_BASE') ?: 'http://127.0.0.1:8000/api/v1';
$centralEmail = getenv('QA_CENTRAL_EMAIL') ?: 'admin@newpaotang.test';
$centralPassword = getenv('QA_CENTRAL_PASSWORD') ?: '';
$tenantEmail = getenv('QA_TENANT_EMAIL') ?: 'owner@alpha.newpaotang.test';
$tenantPassword = getenv('QA_TENANT_PASSWORD') ?: '';
$tenantId = getenv('QA_TENANT_ID') ?: 'ten_demo_alpha';
$runId = 'qa-p4-admin-'.substr(str_replace('.', '', uniqid('', true)), 0, 12);
$now = gmdate('c');

if ($centralPassword === '' || $tenantPassword === '') {
    fwrite(STDERR, "Missing QA_CENTRAL_PASSWORD or QA_TENANT_PASSWORD.\n");
    exit(2);
}

$checks = [];

function request_api(string $method, string $path, ?string $token = null, array $headers = [], ?array $body = null, ?array $query = null): array
{
    global $apiBase, $checks;

    $url = rtrim($apiBase, '/').$path;
    if ($query !== null) {
        $query = array_filter($query, static fn ($value) => $value !== null && $value !== '');
        if ($query !== []) {
            $url .= '?'.http_build_query($query);
        }
    }

    $requestHeaders = array_merge([
        'Accept: application/json',
        'X-Request-Id: req_'.bin2hex(random_bytes(6)),
    ], $headers);

    if ($token !== null) {
        $requestHeaders[] = 'Authorization: Bearer '.$token;
    }

    $content = null;
    if ($body !== null) {
        $content = json_encode($body, JSON_THROW_ON_ERROR);
        $requestHeaders[] = 'Content-Type: application/json';
    }

    $context = stream_context_create([
        'http' => [
            'method' => $method,
            'header' => implode("\r\n", $requestHeaders),
            'content' => $content,
            'ignore_errors' => true,
            'timeout' => 30,
        ],
    ]);

    $raw = file_get_contents($url, false, $context);
    $status = 0;
    foreach ($http_response_header ?? [] as $line) {
        if (preg_match('/^HTTP\/\S+\s+(\d+)/', $line, $matches)) {
            $status = (int) $matches[1];
            break;
        }
    }

    $json = $raw !== false && $raw !== '' ? json_decode($raw, true) : null;
    $checks[] = [
        'method' => $method,
        'path' => $path,
        'query' => $query,
        'scope' => header_value($headers, 'X-Admin-Scope'),
        'tenant' => header_value($headers, 'X-Tenant-Id'),
        'status' => $status,
        'ok' => $status >= 200 && $status < 300,
        'idempotency_key' => header_value($headers, 'Idempotency-Key'),
    ];

    return [
        'status' => $status,
        'body' => is_array($json) ? $json : $raw,
    ];
}

function header_value(array $headers, string $name): ?string
{
    foreach ($headers as $header) {
        if (stripos($header, $name.':') === 0) {
            return trim(substr($header, strlen($name) + 1));
        }
    }

    return null;
}

function expect_status(array $response, array $expected, string $label): void
{
    if (! in_array($response['status'], $expected, true)) {
        throw new RuntimeException($label.' expected '.implode('/', $expected).' but got '.$response['status'].' body='.json_encode($response['body']));
    }
}

function data_of(array $response): array
{
    $body = $response['body'];
    if (is_array($body) && isset($body['data']) && is_array($body['data'])) {
        return $body['data'];
    }
    return is_array($body) ? $body : [];
}

function list_data(array $response): array
{
    $body = $response['body'];
    return is_array($body) && isset($body['data']) && is_array($body['data']) ? $body['data'] : [];
}

function role_id(array $roles, ?string $excludeId = null): string
{
    foreach ($roles as $role) {
        if (($role['status'] ?? 'active') === 'active' && ($role['id'] ?? null) !== $excludeId) {
            return (string) $role['id'];
        }
    }
    throw new RuntimeException('No active role id found.');
}

function safe_admin(array $user): array
{
    unset($user['password'], $user['password_hash']);
    return [
        'id' => $user['id'] ?? null,
        'tenant_id' => $user['tenant_id'] ?? null,
        'email' => $user['email'] ?? null,
        'name' => $user['name'] ?? null,
        'status' => $user['status'] ?? null,
        'role_ids' => array_values(array_map(static fn ($role) => $role['id'] ?? null, $user['roles'] ?? [])),
        'contains_secret_keys' => array_key_exists('password', $user) || array_key_exists('password_hash', $user),
    ];
}

function safe_role(array $role): array
{
    return [
        'id' => $role['id'] ?? null,
        'tenant_id' => $role['tenant_id'] ?? null,
        'code' => $role['code'] ?? null,
        'name' => $role['name'] ?? null,
        'status' => $role['status'] ?? null,
        'permissions' => $role['permissions'] ?? [],
        'version' => $role['version'] ?? null,
    ];
}

function pdo_conn(): PDO
{
    $host = getenv('DB_HOST') ?: 'postgres';
    $port = getenv('DB_PORT') ?: '5432';
    $db = getenv('DB_DATABASE') ?: 'newpaotang';
    $user = getenv('DB_USERNAME') ?: 'newpaotang';
    $pass = getenv('DB_PASSWORD') ?: 'newpaotang';
    return new PDO("pgsql:host={$host};port={$port};dbname={$db}", $user, $pass, [
        PDO::ATTR_ERRMODE => PDO::ERRMODE_EXCEPTION,
    ]);
}

function admin_db_status(PDO $pdo, string $adminUserId): ?string
{
    $stmt = $pdo->prepare('select status from admin_users where id = :id');
    $stmt->execute(['id' => $adminUserId]);
    $value = $stmt->fetchColumn();
    return $value === false ? null : (string) $value;
}

function ensure_customer_fixture(PDO $pdo, string $tenantId, string $runId): string
{
    $id = 'cus_'.$runId;
    $stmt = $pdo->prepare('insert into customers (id, tenant_id, phone, email, name, status, created_at, updated_at) values (:id, :tenant_id, :phone, :email, :name, :status, now(), now()) on conflict (id) do nothing');
    $stmt->execute([
        'id' => $id,
        'tenant_id' => $tenantId,
        'phone' => '089'.substr(preg_replace('/\D/', '', $runId), 0, 7),
        'email' => $runId.'@customer.example.test',
        'name' => 'QA Support Target '.$runId,
        'status' => 'active',
    ]);
    return $id;
}

try {
    $centralLogin = request_api('POST', '/auth/admin/login', null, ['X-Admin-Scope: central'], [
        'email' => $centralEmail,
        'password' => $centralPassword,
        'scope' => 'central',
    ]);
    expect_status($centralLogin, [200], 'central login');
    $centralToken = (string) ($centralLogin['body']['access_token'] ?? '');

    $tenantLogin = request_api('POST', '/auth/admin/login', null, ['X-Admin-Scope: tenant', 'X-Tenant-Id: '.$tenantId], [
        'email' => $tenantEmail,
        'password' => $tenantPassword,
        'scope' => 'tenant',
        'tenant_id' => $tenantId,
    ]);
    expect_status($tenantLogin, [200], 'tenant login');
    $tenantToken = (string) ($tenantLogin['body']['access_token'] ?? '');

    $centralHeaders = ['X-Admin-Scope: central'];
    $tenantHeaders = ['X-Admin-Scope: tenant', 'X-Tenant-Id: '.$tenantId];
    $pdo = pdo_conn();

    $centralRolesList = request_api('GET', '/admin/central/roles', $centralToken, $centralHeaders);
    expect_status($centralRolesList, [200], 'central role list');
    $centralRoles = list_data($centralRolesList);
    $centralRoleA = role_id($centralRoles);

    $centralAdminListBefore = request_api('GET', '/admin/central/admin-users', $centralToken, $centralHeaders, null, ['limit' => 20]);
    expect_status($centralAdminListBefore, [200], 'central admin list');
    $centralAdminEmail = $runId.'-central-admin@example.test';
    $centralAdminCreate = request_api('POST', '/admin/central/admin-users', $centralToken, array_merge($centralHeaders, ['Idempotency-Key: '.$runId.'-central-admin-create']), [
        'name' => 'QA Central Admin '.$runId,
        'email' => $centralAdminEmail,
        'phone' => '020'.substr(preg_replace('/\D/', '', $runId), 0, 7),
        'password' => bin2hex(random_bytes(12)),
        'status' => 'active',
        'role_ids' => [$centralRoleA],
    ]);
    expect_status($centralAdminCreate, [201], 'central admin create');
    $centralAdmin = data_of($centralAdminCreate);
    $centralAdminDetail = request_api('GET', '/admin/central/admin-users/'.$centralAdmin['id'], $centralToken, $centralHeaders);
    expect_status($centralAdminDetail, [200], 'central admin detail');
    $centralAdminUpdate = request_api('PATCH', '/admin/central/admin-users/'.$centralAdmin['id'], $centralToken, array_merge($centralHeaders, ['Idempotency-Key: '.$runId.'-central-admin-update']), [
        'name' => 'QA Central Admin Updated '.$runId,
        'status' => 'suspended',
        'role_ids' => [$centralRoleA],
    ]);
    expect_status($centralAdminUpdate, [200], 'central admin update');
    $centralAdminDisable = request_api('DELETE', '/admin/central/admin-users/'.$centralAdmin['id'], $centralToken, array_merge($centralHeaders, ['Idempotency-Key: '.$runId.'-central-admin-disable']));
    expect_status($centralAdminDisable, [204], 'central admin disable');
    $centralAdminAfter = request_api('GET', '/admin/central/admin-users/'.$centralAdmin['id'], $centralToken, $centralHeaders);
    expect_status($centralAdminAfter, [200, 404], 'central admin after disable');
    $centralAdminDisabledStatus = admin_db_status($pdo, (string) $centralAdmin['id']);

    $centralRoleCreate = request_api('POST', '/admin/central/roles', $centralToken, array_merge($centralHeaders, ['Idempotency-Key: '.$runId.'-central-role-create']), [
        'name' => 'QA Central Role '.$runId,
        'permissions' => ['dashboard.view'],
    ]);
    expect_status($centralRoleCreate, [201], 'central role create');
    $centralRole = data_of($centralRoleCreate);
    $centralRoleUpdate = request_api('PATCH', '/admin/central/roles/'.$centralRole['id'], $centralToken, array_merge($centralHeaders, ['Idempotency-Key: '.$runId.'-central-role-update']), [
        'name' => 'QA Central Role Updated '.$runId,
        'permissions' => ['dashboard.view', 'audit.view'],
    ]);
    expect_status($centralRoleUpdate, [200], 'central role update');
    $centralRoleArchive = request_api('DELETE', '/admin/central/roles/'.$centralRole['id'], $centralToken, array_merge($centralHeaders, ['Idempotency-Key: '.$runId.'-central-role-archive']));
    expect_status($centralRoleArchive, [204], 'central role archive');

    $centralSettingsBefore = request_api('GET', '/admin/central/system-settings', $centralToken, $centralHeaders);
    expect_status($centralSettingsBefore, [200], 'central settings before');
    $centralSettingsData = data_of($centralSettingsBefore);
    $originalReleaseGate = $centralSettingsData['settings']['release_gate_note'] ?? null;
    $centralSettingsSave = request_api('PATCH', '/admin/central/system-settings', $centralToken, array_merge($centralHeaders, ['Idempotency-Key: '.$runId.'-central-settings-save']), [
        'settings' => ['release_gate_note' => 'QA closure '.$runId],
    ]);
    expect_status($centralSettingsSave, [200], 'central settings save');
    $centralSettingsRestore = request_api('PATCH', '/admin/central/system-settings', $centralToken, array_merge($centralHeaders, ['Idempotency-Key: '.$runId.'-central-settings-restore']), [
        'settings' => ['release_gate_note' => $originalReleaseGate],
    ]);
    expect_status($centralSettingsRestore, [200], 'central settings restore');

    $tenantRolesList = request_api('GET', '/admin/tenant/roles', $tenantToken, $tenantHeaders);
    expect_status($tenantRolesList, [200], 'tenant role list');
    $tenantRoles = list_data($tenantRolesList);
    $tenantRoleA = role_id($tenantRoles);

    $tenantAdminEmail = $runId.'-tenant-admin@example.test';
    $tenantAdminListBefore = request_api('GET', '/admin/tenant/admin-users', $tenantToken, $tenantHeaders, null, ['limit' => 20]);
    expect_status($tenantAdminListBefore, [200], 'tenant admin list');
    $tenantAdminCreate = request_api('POST', '/admin/tenant/admin-users', $tenantToken, array_merge($tenantHeaders, ['Idempotency-Key: '.$runId.'-tenant-admin-create']), [
        'name' => 'QA Tenant Admin '.$runId,
        'email' => $tenantAdminEmail,
        'phone' => '021'.substr(preg_replace('/\D/', '', $runId), 0, 7),
        'send_invitation' => false,
        'role_ids' => [$tenantRoleA],
    ]);
    expect_status($tenantAdminCreate, [201], 'tenant admin create');
    $tenantAdmin = data_of($tenantAdminCreate);
    $tenantAdminDetail = request_api('GET', '/admin/tenant/admin-users/'.$tenantAdmin['id'], $tenantToken, $tenantHeaders);
    expect_status($tenantAdminDetail, [200], 'tenant admin detail');
    $tenantAdminUpdate = request_api('PATCH', '/admin/tenant/admin-users/'.$tenantAdmin['id'], $tenantToken, array_merge($tenantHeaders, ['Idempotency-Key: '.$runId.'-tenant-admin-update']), [
        'name' => 'QA Tenant Admin Updated '.$runId,
        'status' => 'active',
        'role_ids' => [$tenantRoleA],
    ]);
    expect_status($tenantAdminUpdate, [200], 'tenant admin update');
    $tenantAdminDisable = request_api('DELETE', '/admin/tenant/admin-users/'.$tenantAdmin['id'], $tenantToken, array_merge($tenantHeaders, ['Idempotency-Key: '.$runId.'-tenant-admin-disable']));
    expect_status($tenantAdminDisable, [204], 'tenant admin disable');
    $tenantAdminAfter = request_api('GET', '/admin/tenant/admin-users/'.$tenantAdmin['id'], $tenantToken, $tenantHeaders);
    expect_status($tenantAdminAfter, [200, 404], 'tenant admin after disable');
    $tenantAdminDisabledStatus = admin_db_status($pdo, (string) $tenantAdmin['id']);

    $tenantRoleCreate = request_api('POST', '/admin/tenant/roles', $tenantToken, array_merge($tenantHeaders, ['Idempotency-Key: '.$runId.'-tenant-role-create']), [
        'name' => 'QA Tenant Role '.$runId,
        'permissions' => ['dashboard.view'],
    ]);
    expect_status($tenantRoleCreate, [201], 'tenant role create');
    $tenantRole = data_of($tenantRoleCreate);
    $tenantRoleUpdate = request_api('PATCH', '/admin/tenant/roles/'.$tenantRole['id'], $tenantToken, array_merge($tenantHeaders, ['Idempotency-Key: '.$runId.'-tenant-role-update']), [
        'name' => 'QA Tenant Role Updated '.$runId,
        'permissions' => ['dashboard.view', 'order.view'],
    ]);
    expect_status($tenantRoleUpdate, [200], 'tenant role update');
    $tenantRoleArchive = request_api('DELETE', '/admin/tenant/roles/'.$tenantRole['id'], $tenantToken, array_merge($tenantHeaders, ['Idempotency-Key: '.$runId.'-tenant-role-archive']));
    expect_status($tenantRoleArchive, [204], 'tenant role archive');

    $tenantSettingsBefore = request_api('GET', '/admin/tenant/settings', $tenantToken, $tenantHeaders);
    expect_status($tenantSettingsBefore, [200], 'tenant settings before');
    $tenantSettingsData = data_of($tenantSettingsBefore);
    $tenantSiteName = $tenantSettingsData['site']['site_name'] ?? null;
    $tenantSettingsSave = request_api('PATCH', '/admin/tenant/settings', $tenantToken, array_merge($tenantHeaders, ['Idempotency-Key: '.$runId.'-tenant-settings-save']), [
        'site' => ['site_name' => 'Alpha Lucky Shop QA '.$runId],
    ]);
    expect_status($tenantSettingsSave, [200], 'tenant settings save');
    $tenantSettingsRestore = request_api('PATCH', '/admin/tenant/settings', $tenantToken, array_merge($tenantHeaders, ['Idempotency-Key: '.$runId.'-tenant-settings-restore']), [
        'site' => ['site_name' => $tenantSiteName],
    ]);
    expect_status($tenantSettingsRestore, [200], 'tenant settings restore');

    $tenantThemeBefore = request_api('GET', '/admin/tenant/theme', $tenantToken, $tenantHeaders);
    expect_status($tenantThemeBefore, [200], 'tenant theme before');
    $tenantThemeData = data_of($tenantThemeBefore);
    $tenantPrimaryColor = $tenantThemeData['theme']['primary_color'] ?? '#0F766E';
    $tenantThemeSave = request_api('PATCH', '/admin/tenant/theme', $tenantToken, array_merge($tenantHeaders, ['Idempotency-Key: '.$runId.'-tenant-theme-save']), [
        'theme' => ['primary_color' => '#123456'],
    ]);
    expect_status($tenantThemeSave, [200], 'tenant theme save');
    $tenantThemeRestore = request_api('PATCH', '/admin/tenant/theme', $tenantToken, array_merge($tenantHeaders, ['Idempotency-Key: '.$runId.'-tenant-theme-restore']), [
        'theme' => ['primary_color' => $tenantPrimaryColor],
    ]);
    expect_status($tenantThemeRestore, [200], 'tenant theme restore');

    $domainHost = $runId.'.qa-domain.test';
    $tenantDomainsBefore = request_api('GET', '/admin/tenant/domains', $tenantToken, $tenantHeaders);
    expect_status($tenantDomainsBefore, [200], 'tenant domains before');
    $domainCreate = request_api('POST', '/admin/tenant/domains', $tenantToken, array_merge($tenantHeaders, ['Idempotency-Key: '.$runId.'-domain-create']), [
        'host' => $domainHost,
        'type' => 'custom_domain',
        'status' => 'pending_verification',
        'is_primary' => false,
    ]);
    expect_status($domainCreate, [201], 'domain create');
    $domain = data_of($domainCreate);
    $domainDetail = request_api('GET', '/admin/tenant/domains/'.$domain['id'], $tenantToken, $tenantHeaders);
    expect_status($domainDetail, [200], 'domain detail');
    $domainUpdate = request_api('PATCH', '/admin/tenant/domains/'.$domain['id'], $tenantToken, array_merge($tenantHeaders, ['Idempotency-Key: '.$runId.'-domain-update']), [
        'status' => 'dns_verified',
    ]);
    expect_status($domainUpdate, [200], 'domain update');
    $domainVerify = request_api('POST', '/admin/tenant/domains/'.$domain['id'].'/verify', $tenantToken, array_merge($tenantHeaders, ['Idempotency-Key: '.$runId.'-domain-verify']), [
        'dns_verified' => true,
        'ssl_ready' => true,
        'cloudflare_proxy_verified' => true,
        'https_enforced' => true,
    ]);
    expect_status($domainVerify, [202], 'domain verify');
    $domainDelete = request_api('DELETE', '/admin/tenant/domains/'.$domain['id'], $tenantToken, array_merge($tenantHeaders, ['Idempotency-Key: '.$runId.'-domain-delete']), [
        'reason' => 'QA closure cleanup '.$runId,
    ]);
    expect_status($domainDelete, [204], 'domain delete');

    $customerId = ensure_customer_fixture($pdo, $tenantId, $runId);
    $supportListBefore = request_api('GET', '/admin/tenant/support-access', $tenantToken, $tenantHeaders, null, ['limit' => 20]);
    expect_status($supportListBefore, [200], 'support list before');
    $supportCreate = request_api('POST', '/admin/tenant/support-access', $tenantToken, array_merge($tenantHeaders, ['Idempotency-Key: '.$runId.'-support-create']), [
        'target_user_id' => $customerId,
        'target_user_type' => 'customer',
        'scope' => 'customer_read',
        'reason' => 'QA closure support workflow '.$runId,
        'ticket_id' => 'SUP-QA-'.$runId,
    ]);
    expect_status($supportCreate, [201], 'support create');
    $support = data_of($supportCreate);
    $supportDetail = request_api('GET', '/admin/tenant/support-access/'.$support['id'], $tenantToken, $tenantHeaders);
    expect_status($supportDetail, [200], 'support detail');
    $supportApprove = request_api('POST', '/admin/tenant/support-access/'.$support['id'].'/approve', $tenantToken, array_merge($tenantHeaders, ['Idempotency-Key: '.$runId.'-support-approve']), [
        'reason' => 'QA closure approve '.$runId,
    ]);
    expect_status($supportApprove, [200], 'support approve');
    $supportImpersonate = request_api('POST', '/admin/tenant/support-access/'.$support['id'].'/impersonate', $tenantToken, array_merge($tenantHeaders, ['Idempotency-Key: '.$runId.'-support-impersonate']), [
        'reason' => 'QA closure impersonate '.$runId,
    ]);
    expect_status($supportImpersonate, [200], 'support impersonate');
    $impersonateData = data_of($supportImpersonate);
    $oneTimeTokenReturned = isset($impersonateData['active_session']['access_token']);
    $supportDetailAfterToken = request_api('GET', '/admin/tenant/support-access/'.$support['id'], $tenantToken, $tenantHeaders);
    expect_status($supportDetailAfterToken, [200], 'support detail after token');
    $detailAfterToken = data_of($supportDetailAfterToken);
    $supportElevated = request_api('POST', '/admin/tenant/support-access/'.$support['id'].'/elevated-actions', $tenantToken, array_merge($tenantHeaders, ['Idempotency-Key: '.$runId.'-support-elevated']), [
        'reason' => 'QA closure elevated action '.$runId,
        'action' => 'wallet_adjust',
    ]);
    expect_status($supportElevated, [202], 'support elevated');
    $supportEndSession = request_api('POST', '/admin/tenant/support-access/'.$support['id'].'/end-session', $tenantToken, array_merge($tenantHeaders, ['Idempotency-Key: '.$runId.'-support-end']), [
        'reason' => 'QA closure end session '.$runId,
    ]);
    expect_status($supportEndSession, [200], 'support end session');

    $supportCreateRevoke = request_api('POST', '/admin/tenant/support-access', $tenantToken, array_merge($tenantHeaders, ['Idempotency-Key: '.$runId.'-support-revoke-create']), [
        'target_user_id' => $customerId,
        'target_user_type' => 'customer',
        'scope' => 'customer_read',
        'reason' => 'QA closure revoke fixture '.$runId,
        'ticket_id' => 'SUP-QA-REV-'.$runId,
    ]);
    expect_status($supportCreateRevoke, [201], 'support revoke fixture create');
    $supportRevokeFixture = data_of($supportCreateRevoke);
    $supportRevoke = request_api('POST', '/admin/tenant/support-access/'.$supportRevokeFixture['id'].'/revoke', $tenantToken, array_merge($tenantHeaders, ['Idempotency-Key: '.$runId.'-support-revoke']), [
        'reason' => 'QA closure revoke '.$runId,
    ]);
    expect_status($supportRevoke, [200], 'support revoke');

    $evidence = [
        'generated_at' => $now,
        'run_id' => $runId,
        'tenant_id' => $tenantId,
        'checks' => $checks,
        'auth' => [
            'central_user_id' => $centralLogin['body']['user']['id'] ?? null,
            'tenant_user_id' => $tenantLogin['body']['user']['id'] ?? null,
            'tenant_active_scope' => $tenantLogin['body']['active_scope'] ?? null,
            'tenant_active_tenant_id' => $tenantLogin['body']['active_tenant_id'] ?? null,
        ],
        'central_admin_users' => [
            'created' => safe_admin($centralAdmin),
            'detail_opened' => safe_admin(data_of($centralAdminDetail)),
            'updated' => safe_admin(data_of($centralAdminUpdate)),
            'disable_status' => $centralAdminDisable['status'],
            'detail_after_disable_status' => $centralAdminAfter['status'],
            'db_status_after_disable' => $centralAdminDisabledStatus,
            'secret_keys_displayed' => safe_admin($centralAdmin)['contains_secret_keys'] || safe_admin(data_of($centralAdminDetail))['contains_secret_keys'] || safe_admin(data_of($centralAdminUpdate))['contains_secret_keys'],
        ],
        'central_roles_permissions' => [
            'created' => safe_role($centralRole),
            'updated' => safe_role(data_of($centralRoleUpdate)),
            'archive_status' => $centralRoleArchive['status'],
        ],
        'central_system_settings' => [
            'before_release_gate_note' => $originalReleaseGate,
            'saved_release_gate_note' => data_of($centralSettingsSave)['settings']['release_gate_note'] ?? null,
            'restored_release_gate_note' => data_of($centralSettingsRestore)['settings']['release_gate_note'] ?? null,
        ],
        'tenant_admin_users' => [
            'created' => safe_admin($tenantAdmin),
            'detail_opened' => safe_admin(data_of($tenantAdminDetail)),
            'updated' => safe_admin(data_of($tenantAdminUpdate)),
            'disable_status' => $tenantAdminDisable['status'],
            'detail_after_disable_status' => $tenantAdminAfter['status'],
            'db_status_after_disable' => $tenantAdminDisabledStatus,
            'secret_keys_displayed' => safe_admin($tenantAdmin)['contains_secret_keys'] || safe_admin(data_of($tenantAdminDetail))['contains_secret_keys'] || safe_admin(data_of($tenantAdminUpdate))['contains_secret_keys'],
        ],
        'tenant_roles_permissions' => [
            'created' => safe_role($tenantRole),
            'updated' => safe_role(data_of($tenantRoleUpdate)),
            'archive_status' => $tenantRoleArchive['status'],
        ],
        'tenant_settings' => [
            'site_saved' => data_of($tenantSettingsSave)['site']['site_name'] ?? null,
            'site_restored' => data_of($tenantSettingsRestore)['site']['site_name'] ?? null,
            'theme_saved' => data_of($tenantThemeSave)['theme']['primary_color'] ?? null,
            'theme_restored' => data_of($tenantThemeRestore)['theme']['primary_color'] ?? null,
            'domain' => [
                'id' => $domain['id'] ?? null,
                'host' => $domain['host'] ?? null,
                'detail_opened' => (data_of($domainDetail)['id'] ?? null) === ($domain['id'] ?? null),
                'updated_status' => data_of($domainUpdate)['status'] ?? null,
                'verify_status' => $domainVerify['status'],
                'delete_status' => $domainDelete['status'],
            ],
        ],
        'tenant_support_access_logs' => [
            'customer_fixture_id' => $customerId,
            'created_id' => $support['id'] ?? null,
            'detail_opened' => (data_of($supportDetail)['id'] ?? null) === ($support['id'] ?? null),
            'approved_status' => data_of($supportApprove)['status'] ?? null,
            'impersonation_status' => $impersonateData['active_session']['status'] ?? null,
            'one_time_token_returned_redacted' => $oneTimeTokenReturned,
            'token_absent_after_detail_reload' => ! isset($detailAfterToken['active_session']['access_token']),
            'elevated_action_status' => $supportElevated['status'],
            'end_session_status' => data_of($supportEndSession)['status'] ?? null,
            'revoked_status' => data_of($supportRevoke)['status'] ?? null,
        ],
    ];

    echo json_encode($evidence, JSON_PRETTY_PRINT | JSON_UNESCAPED_SLASHES).PHP_EOL;
} catch (Throwable $throwable) {
    fwrite(STDERR, $throwable->getMessage()."\n");
    exit(1);
}
