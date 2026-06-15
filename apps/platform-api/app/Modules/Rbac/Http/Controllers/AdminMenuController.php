<?php

namespace App\Modules\Rbac\Http\Controllers;

use App\Shared\Auth\AdminSessionContext;
use App\Shared\Auth\ApiErrorResponse;
use App\Modules\Rbac\Services\MenuService;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Routing\Controller;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Schema;

class AdminMenuController extends Controller
{
    private const CENTRAL_REVIEW_MENU_KEYS = [
        'translations',
        'reward_entry',
    ];

    private const TENANT_REVIEW_MENU_KEYS = [
        'topups',
        'exchange_reward',
        'activity_claims',
        'commission_transactions',
        'support_access_logs',
    ];

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
        $menus = $this->withBadgeCounts(
            $menus,
            $this->pendingReviewBadgeCounts($scope, $context->activeTenantId()),
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

            $category = $this->displayCategoryForMenu((string) ($menu['scope_type'] ?? ''), (string) $menu['code'], (string) ($menu['category'] ?? ''));
            if ($category !== '') {
                $item['category'] = $category;
            }

            if (($menu['icon'] ?? null) !== null && $menu['icon'] !== '') {
                $item['icon'] = $menu['icon'];
            }

            if ((int) ($menu['badge_count'] ?? 0) > 0) {
                $item['badge_count'] = (int) $menu['badge_count'];
            }

            $children = $this->toContractMenuItems($menu['children'] ?? []);

            if ($children !== []) {
                $item['children'] = $children;
            }

            return $item;
        }, $menus);
    }

    private function displayCategoryForMenu(string $scope, string $code, string $fallback): string
    {
        if (
            ($scope === 'central' && in_array($code, self::CENTRAL_REVIEW_MENU_KEYS, true))
            || ($scope === 'tenant' && in_array($code, self::TENANT_REVIEW_MENU_KEYS, true))
        ) {
            return 'Review Queue';
        }

        return $fallback;
    }

    /**
     * @param array<int, array<string, mixed>> $menus
     * @param array<string, int> $badgeCounts
     * @return array<int, array<string, mixed>>
     */
    private function withBadgeCounts(array $menus, array $badgeCounts): array
    {
        return array_map(function (array $menu) use ($badgeCounts): array {
            $key = (string) ($menu['code'] ?? '');
            $count = (int) ($badgeCounts[$key] ?? 0);

            if ($count > 0) {
                $menu['badge_count'] = $count;
            }

            if (is_array($menu['children'] ?? null)) {
                $menu['children'] = $this->withBadgeCounts($menu['children'], $badgeCounts);
            }

            return $menu;
        }, $menus);
    }

    /**
     * @return array<string, int>
     */
    private function pendingReviewBadgeCounts(string $scope, ?string $tenantId): array
    {
        if ($scope === 'central') {
            return [
                'translations' => $this->safeCount('system_translation_deploy_requests', fn ($query): mixed => $query->where('status', 'submitted')),
                'reward_entry' => $this->safeCount('reward_entry_sessions', fn ($query): mixed => $query->where('status', 'ready_for_owner')),
            ];
        }

        if ($scope !== 'tenant' || $tenantId === null || $tenantId === '') {
            return [];
        }

        return [
            'topups' => $this->safeCount('topup_requests', fn ($query): mixed => $query
                ->where('tenant_id', $tenantId)
                ->whereIn('status', ['pending', 'processing'])),
            'exchange_reward' => $this->safeCount('reward_claims', fn ($query): mixed => $query
                ->where('tenant_id', $tenantId)
                ->whereIn('status', ['submitted', 'under_review'])),
            'activity_claims' => $this->safeCount('activity_claims', fn ($query): mixed => $query
                ->where('tenant_id', $tenantId)
                ->whereIn('status', ['submitted', 'under_review'])),
            'commission_transactions' => $this->safeCount('affiliate_payouts', fn ($query): mixed => $query
                ->where('tenant_id', $tenantId)
                ->where('status', 'pending')),
            'support_access_logs' => $this->safeCount('support_access_requests', fn ($query): mixed => $query
                ->where('tenant_id', $tenantId)
                ->where('status', 'pending_approval')),
        ];
    }

    private function safeCount(string $table, callable $callback): int
    {
        if (! Schema::hasTable($table)) {
            return 0;
        }

        $query = DB::table($table);
        $callback($query);

        return (int) $query->count();
    }
}
