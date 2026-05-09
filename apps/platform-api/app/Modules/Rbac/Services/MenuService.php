<?php

namespace App\Modules\Rbac\Services;

use App\Models\AdminMenu;
use Illuminate\Support\Collection;

class MenuService
{
    public function __construct(private readonly PermissionService $permissions)
    {
    }

    /**
     * Menu visibility is a convenience layer; endpoint authorization remains in backend policies/middleware.
     *
     * @return array<int, array<string, mixed>>
     */
    public function allowedMenusForAdmin(string $adminUserId, string $scopeType, ?string $scopeId, ?string $tenantId = null): array
    {
        $menus = AdminMenu::query()
            ->where('scope_type', $scopeType)
            ->where('status', 'active')
            ->orderBy('sort_order')
            ->orderBy('code')
            ->get();

        $allowed = $menus->filter(function (object $menu) use ($adminUserId, $scopeType, $scopeId, $tenantId): bool {
            if ($menu->required_permission_code === null || $menu->required_permission_code === '') {
                return false;
            }

            return $this->permissions->adminHasPermission(
                $adminUserId,
                $scopeType,
                $scopeId,
                $menu->required_permission_code,
                $tenantId,
            );
        });

        return $this->toTree($allowed);
    }

    /**
     * @param Collection<int, object> $menus
     * @return array<int, array<string, mixed>>
     */
    private function toTree(Collection $menus): array
    {
        $items = $menus->mapWithKeys(fn (object $menu): array => [
            $menu->id => [
                'id' => $menu->id,
                'code' => $menu->code,
                'label' => $menu->label,
                'route' => $menu->route,
                'category' => $menu->category,
                'icon' => $menu->icon,
                'required_permission_code' => $menu->required_permission_code,
                'children' => [],
            ],
        ])->all();

        $tree = [];

        foreach ($menus as $menu) {
            if ($menu->parent_id !== null && isset($items[$menu->parent_id])) {
                $items[$menu->parent_id]['children'][] = $items[$menu->id];
                continue;
            }

            $tree[] = $items[$menu->id];
        }

        return array_values($tree);
    }
}
