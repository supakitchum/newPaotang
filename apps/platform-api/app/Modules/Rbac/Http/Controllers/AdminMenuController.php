<?php

namespace App\Modules\Rbac\Http\Controllers;

use App\Shared\Auth\AdminSessionContext;
use App\Shared\Auth\ApiErrorResponse;
use App\Modules\Rbac\Services\MenuService;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Routing\Controller;

class AdminMenuController extends Controller
{
    public function __construct(private readonly MenuService $menus)
    {
    }

    public function central(Request $request): JsonResponse
    {
        return $this->menuResponse($request, 'central');
    }

    public function tenant(Request $request): JsonResponse
    {
        return $this->menuResponse($request, 'tenant');
    }

    private function menuResponse(Request $request, string $scope): JsonResponse
    {
        $context = $request->attributes->get('admin_session');

        if (! $context instanceof AdminSessionContext || $context->activeScope() !== $scope) {
            return ApiErrorResponse::permissionDenied($request);
        }

        $menus = $this->menus->allowedMenusForAdmin(
            $context->adminUser['id'],
            $scope,
            $context->activeScopeId(),
            $context->activeTenantId(),
        );

        return response()->json([
            'data' => $this->toContractMenuItems($menus),
        ]);
    }

    /**
     * @param array<int, array<string, mixed>> $menus
     * @return array<int, array<string, mixed>>
     */
    private function toContractMenuItems(array $menus): array
    {
        return array_map(function (array $menu): array {
            $item = [
                'key' => $menu['code'],
                'label' => $menu['label'],
            ];

            if (($menu['route'] ?? null) !== null) {
                $item['route'] = $menu['route'];
            }

            if (($menu['category'] ?? null) !== null && $menu['category'] !== '') {
                $item['category'] = $menu['category'];
            }

            if (($menu['icon'] ?? null) !== null && $menu['icon'] !== '') {
                $item['icon'] = $menu['icon'];
            }

            $children = $this->toContractMenuItems($menu['children'] ?? []);

            if ($children !== []) {
                $item['children'] = $children;
            }

            return $item;
        }, $menus);
    }
}
