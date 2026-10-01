<?php

namespace App\Modules\SmsOtp\Http\Controllers;

use App\Modules\Rbac\Services\PermissionService;
use App\Modules\SmsOtp\Services\SmsOtpService;
use App\Shared\Auth\AdminSessionContext;
use App\Shared\Auth\ApiErrorResponse;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Routing\Controller;

class TenantSmsOtpController extends Controller
{
    public function __construct(
        private readonly PermissionService $permissions,
        private readonly SmsOtpService $otp,
    ) {
    }

    public function show(Request $request): JsonResponse
    {
        $context = $this->tenantContext($request, 'sms_otp.view');

        return $context instanceof AdminSessionContext
            ? response()->json($this->otp->settings((string) $context->activeTenantId(), $request->query()))
            : $context;
    }

    public function update(Request $request): JsonResponse
    {
        $context = $this->tenantContext($request, 'sms_otp.manage');

        if (! $context instanceof AdminSessionContext) {
            return $context;
        }

        return $this->writeResult($request, $this->otp->updateProvider((string) $context->activeTenantId(), $request->all()));
    }

    public function testSend(Request $request): JsonResponse
    {
        $context = $this->tenantContext($request, 'sms_otp.manage');

        if (! $context instanceof AdminSessionContext) {
            return $context;
        }

        return $this->writeResult($request, $this->otp->testSend((string) $context->activeTenantId(), $request->all()));
    }

    public function updateProviderStatus(Request $request, string $provider_id): JsonResponse
    {
        $context = $this->tenantContext($request, 'sms_otp.manage');

        if (! $context instanceof AdminSessionContext) {
            return $context;
        }

        return $this->writeResult($request, $this->otp->updateProviderStatus((string) $context->activeTenantId(), $provider_id, $request->all()));
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
        if (($result['error'] ?? null) === 'validation_failed') {
            return ApiErrorResponse::validationFailed($request, $result['errors'] ?? ['payload' => ['The request payload is invalid.']]);
        }

        if (in_array(($result['error'] ?? null), ['not_found', 'sms_encryption_failed', 'sms_test_failed', 'provider_not_configured', 'storage_unavailable'], true)) {
            return ApiErrorResponse::make(
                $request,
                $result['status'] ?? 503,
                (string) $result['error'],
                (string) ($result['message'] ?? 'เกิดข้อผิดพลาดในการบันทึก SMS OTP กรุณากด Save ใหม่อีกครั้ง'),
                $result['details'] ?? [],
            );
        }

        return response()->json($result['resource'] ?? []);
    }
}
