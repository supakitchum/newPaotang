<?php

namespace App\Modules\StorageConnections\Http\Controllers;

use App\Modules\Rbac\Services\PermissionService;
use App\Modules\StorageConnections\Services\CentralStorageConnectionService;
use App\Shared\Auth\AdminSessionContext;
use App\Shared\Auth\ApiErrorResponse;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Routing\Controller;

class CentralStorageConnectionController extends Controller
{
    private const PLATFORM_OWNER_ID = 'adm_platform_owner';

    public function __construct(
        private readonly PermissionService $permissions,
        private readonly CentralStorageConnectionService $storage,
    ) {
    }

    public function show(Request $request): JsonResponse
    {
        $context = $this->platformOwnerContext($request, 'storage_connection.view');

        return $context instanceof AdminSessionContext
            ? response()->json($this->storage->show())
            : $context;
    }

    public function update(Request $request): JsonResponse
    {
        $context = $this->platformOwnerContext($request, 'storage_connection.manage');

        return $context instanceof AdminSessionContext
            ? $this->writeResult($request, $this->storage->update($request->all(), (string) $context->adminUser['id']))
            : $context;
    }

    public function updateRoutes(Request $request): JsonResponse
    {
        $context = $this->platformOwnerContext($request, 'storage_connection.manage');

        return $context instanceof AdminSessionContext
            ? $this->writeResult($request, $this->storage->updateRoutes($request->all()))
            : $context;
    }

    public function disconnect(Request $request): JsonResponse
    {
        $context = $this->platformOwnerContext($request, 'storage_connection.manage');

        return $context instanceof AdminSessionContext
            ? $this->writeResult($request, $this->storage->disconnect())
            : $context;
    }

    public function test(Request $request): JsonResponse
    {
        $context = $this->platformOwnerContext($request, 'storage_connection.manage');

        return $context instanceof AdminSessionContext
            ? $this->writeResult($request, $this->storage->testConnection())
            : $context;
    }

    private function platformOwnerContext(Request $request, string $permissionCode): AdminSessionContext|JsonResponse
    {
        $context = $request->attributes->get('admin_session');

        if (! $context instanceof AdminSessionContext) {
            return ApiErrorResponse::authenticationRequired($request);
        }

        if ($context->activeScope() !== 'central') {
            return ApiErrorResponse::permissionDenied($request);
        }

        if (($context->adminUser['id'] ?? null) !== self::PLATFORM_OWNER_ID) {
            return ApiErrorResponse::permissionDenied($request);
        }

        if (! $this->permissions->adminHasPermission(
            (string) $context->adminUser['id'],
            'central',
            $context->activeScopeId(),
            $permissionCode,
            null,
        )) {
            return ApiErrorResponse::permissionDenied($request);
        }

        return $context;
    }

    private function writeResult(Request $request, array $result): JsonResponse
    {
        if (($result['error'] ?? null) === 'validation_failed') {
            return ApiErrorResponse::validationFailed($request, $result['errors'] ?? ['payload' => ['The request payload is invalid.']]);
        }

        if (in_array(($result['error'] ?? null), [
            'storage_encryption_not_configured',
            'storage_encryption_failed',
            'storage_connection_missing',
            'storage_connection_incomplete',
            's3_adapter_missing',
            'storage_test_failed',
        ], true)) {
            return ApiErrorResponse::make(
                $request,
                ($result['error'] ?? null) === 'storage_connection_missing' ? 404 : 503,
                (string) $result['error'],
                (string) ($result['message'] ?? 'Storage connection failed.'),
                $result['details'] ?? [],
            );
        }

        return response()->json($result['resource'] ?? []);
    }
}
