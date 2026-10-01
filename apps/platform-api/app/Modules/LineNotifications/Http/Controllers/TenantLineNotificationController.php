<?php

namespace App\Modules\LineNotifications\Http\Controllers;

use App\Modules\LineNotifications\Services\TenantLineNotificationService;
use App\Modules\Rbac\Services\PermissionService;
use App\Shared\Auth\AdminSessionContext;
use App\Shared\Auth\ApiErrorResponse;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Routing\Controller;

class TenantLineNotificationController extends Controller
{
    public function __construct(
        private readonly PermissionService $permissions,
        private readonly TenantLineNotificationService $notifications,
    ) {
    }

    public function show(Request $request): JsonResponse
    {
        $context = $this->tenantContext($request, 'line_notification.view');

        return $context instanceof AdminSessionContext
            ? response()->json($this->notifications->showSettings((string) $context->activeTenantId()))
            : $context;
    }

    public function updateConnection(Request $request): JsonResponse
    {
        $context = $this->tenantContext($request, 'line_notification.manage');

        if (! $context instanceof AdminSessionContext) {
            return $context;
        }

        $result = $this->notifications->updateConnection((string) $context->activeTenantId(), $request->all());

        return $this->writeResult($request, $result);
    }

    public function disconnectConnection(Request $request): JsonResponse
    {
        $context = $this->tenantContext($request, 'line_notification.manage');

        if (! $context instanceof AdminSessionContext) {
            return $context;
        }

        $result = $this->notifications->disconnectConnection((string) $context->activeTenantId());

        return $this->writeResult($request, $result);
    }

    public function templates(Request $request): JsonResponse
    {
        $context = $this->tenantContext($request, 'line_notification.view');

        return $context instanceof AdminSessionContext
            ? response()->json(['data' => $this->notifications->templates((string) $context->activeTenantId())])
            : $context;
    }

    public function updateTemplate(Request $request, string $event_key): JsonResponse
    {
        $context = $this->tenantContext($request, 'line_notification.manage');

        if (! $context instanceof AdminSessionContext) {
            return $context;
        }

        $result = $this->notifications->updateTemplate((string) $context->activeTenantId(), $event_key, $request->all());

        return $this->writeResult($request, $result);
    }

    public function previewTemplate(Request $request, string $event_key): JsonResponse
    {
        $context = $this->tenantContext($request, 'line_notification.view');

        if (! $context instanceof AdminSessionContext) {
            return $context;
        }

        $result = $this->notifications->previewTemplate((string) $context->activeTenantId(), $event_key, $request->all());

        return $this->writeResult($request, $result);
    }

    public function linkedCustomers(Request $request): JsonResponse
    {
        $context = $this->tenantContext($request, 'line_notification.view');

        return $context instanceof AdminSessionContext
            ? response()->json($this->notifications->linkedCustomers((string) $context->activeTenantId(), $request->query()))
            : $context;
    }

    public function deliveries(Request $request): JsonResponse
    {
        $context = $this->tenantContext($request, 'line_notification.view');

        return $context instanceof AdminSessionContext
            ? response()->json($this->notifications->deliveries((string) $context->activeTenantId(), $request->query()))
            : $context;
    }

    public function testSend(Request $request): JsonResponse
    {
        $context = $this->tenantContext($request, 'line_notification.manage');

        if (! $context instanceof AdminSessionContext) {
            return $context;
        }

        $result = $this->notifications->testSend((string) $context->activeTenantId(), $request->all());

        return $this->writeResult($request, $result);
    }

    private function tenantContext(Request $request, string $permissionCode): AdminSessionContext|JsonResponse
    {
        $context = $request->attributes->get('admin_session');

        if (! $context instanceof AdminSessionContext) {
            return ApiErrorResponse::authenticationRequired($request);
        }

        if ($context->activeScope() !== 'tenant' || $context->activeTenantId() === null || $context->activeTenantId() === '') {
            return ApiErrorResponse::permissionDenied($request);
        }

        if (! $this->permissions->adminHasPermission(
            $context->adminUser['id'],
            'tenant',
            $context->activeScopeId(),
            $permissionCode,
            $context->activeTenantId(),
        )) {
            return ApiErrorResponse::permissionDenied($request);
        }

        return $context;
    }

    private function writeResult(Request $request, array $result): JsonResponse
    {
        if (($result['error'] ?? null) === 'validation_failed' || ($result['error'] ?? null) === 'line_verification_failed') {
            return ApiErrorResponse::validationFailed($request, $result['errors'] ?? ['payload' => ['The request payload is invalid.']]);
        }

        if (in_array(($result['error'] ?? null), ['line_encryption_not_configured', 'line_encryption_failed', 'line_schema_not_ready', 'line_channel_not_ready', 'line_test_send_failed'], true)) {
            return ApiErrorResponse::make(
                $request,
                503,
                (string) $result['error'],
                (string) ($result['message'] ?? 'เกิดข้อผิดพลาดในการบันทึกการเชื่อมต่อ LINE กรุณากด Save ใหม่อีกครั้ง'),
                $result['details'] ?? [],
            );
        }

        if (($result['error'] ?? null) === 'not_found') {
            return ApiErrorResponse::notFound($request);
        }

        return response()->json($result['resource'] ?? []);
    }
}
