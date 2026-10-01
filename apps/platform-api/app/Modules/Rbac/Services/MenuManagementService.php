<?php

namespace App\Modules\Rbac\Services;

use App\Models\AdminMenu;
use App\Models\AdminPermissionCacheVersion;
use App\Models\AdminUserRole;
use App\Models\Permission;
use App\Models\Role;
use App\Models\RoleMenu;
use App\Shared\Audit\AuditLogger;
use App\Shared\Auth\AdminSessionContext;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;

class MenuManagementService
{
    public function __construct(private readonly AuditLogger $auditLogger)
    {
    }

    /**
     * @return array<int, array<string, mixed>>
     */
    public function manageableTree(string $scopeType, ?string $tenantId): array
    {
        $menus = AdminMenu::query()
            ->where('scope_type', $scopeType)
            ->orderBy('sort_order')
            ->orderBy('code')
            ->get()
            ->all();

        $roleIdsByMenu = $this->roleIdsByMenu($scopeType, $tenantId, array_map(
            fn (object $menu): string => (string) $menu->id,
            $menus,
        ));

        return $this->buildTree($menus, $roleIdsByMenu);
    }

    /**
     * @param array<string, mixed> $payload
     * @return array<string, array<int, string>>
     */
    public function validateUpdate(string $scopeType, ?string $tenantId, array $payload): array
    {
        return $this->normalizeUpdateItems($scopeType, $tenantId, $payload)['errors'];
    }

    /**
     * @param array<string, mixed> $payload
     * @return array<int, array<string, mixed>>
     */
    public function updateTree(string $scopeType, ?string $tenantId, array $payload, AdminSessionContext $actor, Request $request): array
    {
        $normalized = $this->normalizeUpdateItems($scopeType, $tenantId, $payload);
        $items = $normalized['items'];

        return DB::transaction(function () use ($scopeType, $tenantId, $payload, $actor, $request, $items): array {
            $now = now();
            $roleIdsInScope = $this->roleIdsForScope($scopeType, $tenantId);

            foreach ($items as $item) {
                $updates = [
                    'parent_id' => $item['parent_id'],
                    'label' => $item['label'],
                    'sort_order' => $item['sort_order'],
                    'updated_at' => $now,
                ];

                if ($item['route_provided']) {
                    $updates['route'] = $item['route'];
                }

                if ($item['category_provided']) {
                    $updates['category'] = $item['category'];
                }

                if ($item['icon_provided']) {
                    $updates['icon'] = $item['icon'];
                }

                if ($item['required_permission_code_provided']) {
                    $updates['required_permission_code'] = $item['required_permission_code'];
                }

                if ($item['status_provided']) {
                    $updates['status'] = $item['status'];
                }

                AdminMenu::query()
                    ->where('id', $item['id'])
                    ->where('scope_type', $scopeType)
                    ->update($updates);

                if (! $item['role_ids_provided']) {
                    continue;
                }

                if ($roleIdsInScope !== []) {
                    RoleMenu::query()
                        ->where('menu_id', $item['id'])
                        ->whereIn('role_id', $roleIdsInScope)
                        ->delete();
                }

                if ($item['role_ids'] === []) {
                    continue;
                }

                RoleMenu::query()->insert(array_map(fn (string $roleId): array => [
                    'role_id' => $roleId,
                    'menu_id' => $item['id'],
                    'created_at' => $now,
                    'updated_at' => $now,
                ], $item['role_ids']));
            }

            $scopeId = $actor->activeScopeId();
            $this->invalidateScopePermissionCaches($scopeId);
            $this->auditMenuChange($actor, $request, $scopeType, $tenantId, $scopeId, $payload, array_column($items, 'id'));

            return $this->manageableTree($scopeType, $tenantId);
        });
    }

    /**
     * @param array<int, object> $menus
     * @param array<string, array<int, string>> $roleIdsByMenu
     * @return array<int, array<string, mixed>>
     */
    private function buildTree(array $menus, array $roleIdsByMenu): array
    {
        $childrenByParent = [];

        foreach ($menus as $menu) {
            $childrenByParent[$menu->parent_id ?? '__root__'][] = $menu;
        }

        $build = function (?string $parentId) use (&$build, $childrenByParent, $roleIdsByMenu): array {
            $items = [];

            foreach ($childrenByParent[$parentId ?? '__root__'] ?? [] as $menu) {
                $items[] = [
                    'id' => (string) $menu->id,
                    'key' => (string) $menu->code,
                    'code' => (string) $menu->code,
                    'label' => (string) $menu->label,
                    'route' => $menu->route,
                    'category' => $menu->category,
                    'icon' => $menu->icon,
                    'required_permission_code' => $menu->required_permission_code,
                    'sort_order' => (int) $menu->sort_order,
                    'status' => (string) $menu->status,
                    'role_ids' => $roleIdsByMenu[(string) $menu->id] ?? [],
                    'children' => $build((string) $menu->id),
                ];
            }

            return $items;
        };

        return $build(null);
    }

    /**
     * @param array<string, mixed> $payload
     * @return array{errors: array<string, array<int, string>>, items: array<int, array<string, mixed>>}
     */
    private function normalizeUpdateItems(string $scopeType, ?string $tenantId, array $payload): array
    {
        $errors = [];
        $items = [];

        if (! array_key_exists('items', $payload) || ! is_array($payload['items'])) {
            return [
                'errors' => ['items' => ['The items field must be an array.']],
                'items' => [],
            ];
        }

        $menusById = [];
        $menusByCode = [];

        foreach (AdminMenu::query()->where('scope_type', $scopeType)->get()->all() as $menu) {
            $menusById[(string) $menu->id] = $menu;
            $menusByCode[(string) $menu->code] = $menu;
        }

        $permissionCodes = $this->permissionCodesForScope($scopeType);
        $roleIdsInScope = $this->roleIdsForScope($scopeType, $tenantId);
        $seenMenuIds = [];
        $seenMenuCodes = [];
        $ordersByParent = [];

        $walk = function (array $nodes, ?string $parentId, string $path) use (
            &$walk,
            &$errors,
            &$items,
            &$seenMenuIds,
            &$seenMenuCodes,
            &$ordersByParent,
            $menusById,
            $menusByCode,
            $permissionCodes,
            $roleIdsInScope,
            $scopeType
        ): void {
            foreach ($nodes as $index => $node) {
                $nodePath = $path.'.'.$index;

                if (! is_array($node)) {
                    $errors[$nodePath][] = 'Each menu item must be an object.';
                    continue;
                }

                $menu = $this->resolveMenuForNode($scopeType, $menusById, $menusByCode, $node, $nodePath, $errors);

                if ($menu === null) {
                    if (array_key_exists('children', $node) && is_array($node['children'])) {
                        $walk($node['children'], null, $nodePath.'.children');
                    }

                    continue;
                }

                $menuId = (string) $menu->id;
                $menuCode = (string) $menu->code;

                if (isset($seenMenuIds[$menuId])) {
                    $errors[$nodePath.'.id'][] = 'Duplicate menu id in tree.';
                }

                if (isset($seenMenuCodes[$menuCode])) {
                    $errors[$nodePath.'.key'][] = 'Duplicate menu key in tree.';
                }

                $seenMenuIds[$menuId] = true;
                $seenMenuCodes[$menuCode] = true;

                if (! array_key_exists('label', $node) || ! is_string($node['label']) || trim($node['label']) === '') {
                    $errors[$nodePath.'.label'][] = 'The label field is required.';
                }

                $route = null;
                $routeProvided = array_key_exists('route', $node);

                if ($routeProvided) {
                    if ($node['route'] !== null && ! is_string($node['route'])) {
                        $errors[$nodePath.'.route'][] = 'The route field must be a string or null.';
                    } else {
                        $route = $node['route'] === null ? null : trim((string) $node['route']);
                    }
                }

                $category = null;
                $categoryProvided = array_key_exists('category', $node);

                if ($categoryProvided) {
                    if ($node['category'] !== null && ! is_string($node['category'])) {
                        $errors[$nodePath.'.category'][] = 'The category field must be a string or null.';
                    } else {
                        $category = $node['category'] === null ? null : trim((string) $node['category']);
                        $category = $category === '' ? null : $category;

                        if ($category !== null && strlen($category) > 128) {
                            $errors[$nodePath.'.category'][] = 'The category field must be 128 characters or fewer.';
                        }
                    }
                }

                $icon = null;
                $iconProvided = array_key_exists('icon', $node);

                if ($iconProvided) {
                    if ($node['icon'] !== null && ! is_string($node['icon'])) {
                        $errors[$nodePath.'.icon'][] = 'The icon field must be a string or null.';
                    } else {
                        $icon = $node['icon'] === null ? null : trim((string) $node['icon']);
                        $icon = $icon === '' ? null : $icon;

                        if ($icon !== null && strlen($icon) > 128) {
                            $errors[$nodePath.'.icon'][] = 'The icon field must be 128 characters or fewer.';
                        }
                    }
                }

                $requiredPermissionCode = null;
                $requiredPermissionCodeProvided = array_key_exists('required_permission_code', $node);

                if ($requiredPermissionCodeProvided) {
                    if ($node['required_permission_code'] !== null && ! is_string($node['required_permission_code'])) {
                        $errors[$nodePath.'.required_permission_code'][] = 'The required_permission_code field must be a string or null.';
                    } else {
                        $requiredPermissionCode = $node['required_permission_code'] === null
                            ? null
                            : trim((string) $node['required_permission_code']);

                        if ($requiredPermissionCode === '') {
                            $requiredPermissionCode = null;
                        }

                        if ($requiredPermissionCode !== null && ! in_array($requiredPermissionCode, $permissionCodes, true)) {
                            $errors[$nodePath.'.required_permission_code'][] = 'The required_permission_code does not exist in this scope.';
                        }
                    }
                }

                $status = null;
                $statusProvided = array_key_exists('status', $node);

                if ($statusProvided) {
                    if (! is_string($node['status']) || ! in_array($node['status'], ['active', 'inactive', 'archived'], true)) {
                        $errors[$nodePath.'.status'][] = 'The status field must be active, inactive, or archived.';
                    } else {
                        $status = $node['status'];
                    }
                }

                if (array_key_exists('parent_id', $node)) {
                    $providedParentId = $node['parent_id'] === null || $node['parent_id'] === '' ? null : (string) $node['parent_id'];

                    if ($providedParentId !== $parentId) {
                        $errors[$nodePath.'.parent_id'][] = 'The parent_id field must match the submitted tree position.';
                    }
                }

                $sortOrder = $this->sortOrderForNode($node, $index, $nodePath, $errors);
                $parentOrderKey = $parentId ?? '__root__';

                if (isset($ordersByParent[$parentOrderKey][$sortOrder])) {
                    $errors[$nodePath.'.sort_order'][] = 'Duplicate sort_order among sibling menu items.';
                }

                $ordersByParent[$parentOrderKey][$sortOrder] = true;

                $roleIds = [];
                $roleIdsProvided = array_key_exists('role_ids', $node);

                if ($roleIdsProvided) {
                    if (! is_array($node['role_ids'])) {
                        $errors[$nodePath.'.role_ids'][] = 'The role_ids field must be an array.';
                    } else {
                        $roleIds = array_values(array_unique(array_map(
                            fn (mixed $roleId): string => is_string($roleId) ? trim($roleId) : '',
                            $node['role_ids'],
                        )));
                        $roleIds = array_values(array_filter($roleIds, fn (string $roleId): bool => $roleId !== ''));
                        $invalidRoleIds = array_values(array_diff($roleIds, $roleIdsInScope));

                        if ($invalidRoleIds !== []) {
                            $errors[$nodePath.'.role_ids'][] = 'Invalid role ids for '.$scopeType.' scope: '.implode(', ', $invalidRoleIds).'.';
                        }
                    }
                }

                $items[] = [
                    'id' => $menuId,
                    'parent_id' => $parentId,
                    'label' => trim((string) ($node['label'] ?? '')),
                    'route' => $route,
                    'route_provided' => $routeProvided,
                    'category' => $category,
                    'category_provided' => $categoryProvided,
                    'icon' => $icon,
                    'icon_provided' => $iconProvided,
                    'required_permission_code' => $requiredPermissionCode,
                    'required_permission_code_provided' => $requiredPermissionCodeProvided,
                    'status' => $status,
                    'status_provided' => $statusProvided,
                    'sort_order' => $sortOrder,
                    'role_ids' => $roleIds,
                    'role_ids_provided' => $roleIdsProvided,
                ];

                if (array_key_exists('children', $node)) {
                    if (! is_array($node['children'])) {
                        $errors[$nodePath.'.children'][] = 'The children field must be an array.';
                        continue;
                    }

                    $walk($node['children'], $menuId, $nodePath.'.children');
                }
            }
        };

        $walk($payload['items'], null, 'items');

        return ['errors' => $errors, 'items' => $items];
    }

    /**
     * @param array<string, object> $menusById
     * @param array<string, object> $menusByCode
     * @param array<string, mixed> $node
     * @param array<string, array<int, string>> $errors
     */
    private function resolveMenuForNode(string $scopeType, array $menusById, array $menusByCode, array $node, string $nodePath, array &$errors): ?object
    {
        $id = array_key_exists('id', $node) && $node['id'] !== null ? trim((string) $node['id']) : null;
        $key = null;

        if (array_key_exists('key', $node) && $node['key'] !== null) {
            $key = trim((string) $node['key']);
        } elseif (array_key_exists('code', $node) && $node['code'] !== null) {
            $key = trim((string) $node['code']);
        }

        if (($id === null || $id === '') && ($key === null || $key === '')) {
            $errors[$nodePath.'.id'][] = 'Each menu item must include an id or key.';
            return null;
        }

        $menu = null;

        if ($id !== null && $id !== '') {
            $menu = $menusById[$id] ?? null;

            if ($menu === null) {
                $existingScope = AdminMenu::where('id', $id)->value('scope_type');
                $errors[$nodePath.'.id'][] = $existingScope === null
                    ? 'The menu id does not exist.'
                    : 'The menu id belongs to '.$existingScope.' scope, not '.$scopeType.' scope.';

                return null;
            }
        }

        if ($key !== null && $key !== '') {
            if ($menu !== null && $key !== (string) $menu->code) {
                $errors[$nodePath.'.key'][] = 'The menu key does not match the menu id.';
                return null;
            }

            if ($menu === null) {
                $menu = $menusByCode[$key] ?? null;

                if ($menu === null) {
                    $existingScope = AdminMenu::where('code', $key)->value('scope_type');
                    $errors[$nodePath.'.key'][] = $existingScope === null
                        ? 'The menu key does not exist.'
                        : 'The menu key belongs to '.$existingScope.' scope, not '.$scopeType.' scope.';

                    return null;
                }
            }
        }

        return $menu;
    }

    /**
     * @param array<string, mixed> $node
     * @param array<string, array<int, string>> $errors
     */
    private function sortOrderForNode(array $node, int $index, string $nodePath, array &$errors): int
    {
        if (! array_key_exists('sort_order', $node)) {
            return ($index + 1) * 10;
        }

        $sortOrder = filter_var($node['sort_order'], FILTER_VALIDATE_INT);

        if ($sortOrder === false) {
            $errors[$nodePath.'.sort_order'][] = 'The sort_order field must be an integer.';

            return ($index + 1) * 10;
        }

        return $sortOrder;
    }

    /**
     * @return array<int, string>
     */
    private function permissionCodesForScope(string $scopeType): array
    {
        return Permission::query()
            ->where('scope_type', $scopeType)
            ->where('status', 'active')
            ->pluck('code')
            ->all();
    }

    /**
     * @return array<int, string>
     */
    private function roleIdsForScope(string $scopeType, ?string $tenantId): array
    {
        $query = Role::query()
            ->where('scope_type', $scopeType)
            ->where('status', 'active');

        $scopeType === 'tenant'
            ? $query->where('tenant_id', $tenantId)
            : $query->whereNull('tenant_id');

        return $query->pluck('id')->all();
    }

    /**
     * @param array<int, string> $menuIds
     * @return array<string, array<int, string>>
     */
    private function roleIdsByMenu(string $scopeType, ?string $tenantId, array $menuIds): array
    {
        if ($menuIds === []) {
            return [];
        }

        $query = RoleMenu::query()
            ->join('roles', 'roles.id', '=', 'role_menus.role_id')
            ->whereIn('role_menus.menu_id', $menuIds)
            ->where('roles.scope_type', $scopeType)
            ->orderBy('roles.code')
            ->select('role_menus.menu_id', 'role_menus.role_id');

        $scopeType === 'tenant'
            ? $query->where('roles.tenant_id', $tenantId)
            : $query->whereNull('roles.tenant_id');

        $roleIdsByMenu = [];

        foreach ($query->get()->all() as $row) {
            $roleIdsByMenu[(string) $row->menu_id][] = (string) $row->role_id;
        }

        return $roleIdsByMenu;
    }

    private function invalidateScopePermissionCaches(?string $scopeId): void
    {
        if ($scopeId === null || $scopeId === '') {
            return;
        }

        $adminUserIds = AdminUserRole::query()
            ->where('scope_id', $scopeId)
            ->distinct()
            ->pluck('admin_user_id')
            ->all();

        foreach ($adminUserIds as $adminUserId) {
            $updated = AdminPermissionCacheVersion::query()
                ->where('admin_user_id', $adminUserId)
                ->where('scope_id', $scopeId)
                ->increment('version', 1, ['updated_at' => now()]);

            if ($updated > 0) {
                continue;
            }

            AdminPermissionCacheVersion::query()->insert([
                'id' => 'pcv_'.substr(sha1($adminUserId.':'.$scopeId), 0, 20),
                'admin_user_id' => $adminUserId,
                'scope_id' => $scopeId,
                'version' => 2,
                'created_at' => now(),
                'updated_at' => now(),
            ]);
        }
    }

    /**
     * @param array<string, mixed> $payload
     * @param array<int, string> $menuIds
     */
    private function auditMenuChange(
        AdminSessionContext $actor,
        Request $request,
        string $scopeType,
        ?string $tenantId,
        ?string $scopeId,
        array $payload,
        array $menuIds,
    ): void {
        $this->auditLogger->logAdminWrite(
            actorId: $actor->adminUser['id'],
            scopeType: $scopeType,
            action: 'menu.changed',
            targetType: 'admin_menu_tree',
            targetId: $scopeId,
            payload: [
                'idempotency_key' => $request->header('Idempotency-Key'),
                'menu_ids' => $menuIds,
                'payload' => $payload,
            ],
            tenantId: $tenantId,
            requestId: $request->header('X-Request-Id'),
            ipAddress: $request->ip(),
            userAgent: $request->userAgent(),
        );
    }
}
