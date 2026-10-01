<?php

namespace App\Modules\Growth\Http\Controllers;

use App\Shared\Auth\AdminSessionContext;
use App\Shared\Auth\ApiErrorResponse;
use App\Modules\Growth\Services\GrowthService;
use App\Shared\Http\RequestHeaderValidator;
use App\Modules\Rbac\Services\PermissionService;
use App\Modules\Growth\Http\Requests\ReportRequestValidator;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\RedirectResponse;
use Illuminate\Http\Request;
use Illuminate\Routing\Controller;

class ReportController extends Controller
{
    public function __construct(
        private readonly PermissionService $permissions,
        private readonly GrowthService $growth,
        private readonly RequestHeaderValidator $headers,
        private readonly ReportRequestValidator $validator,
    ) {
    }

    public function centralReport(Request $request, string $report_key): JsonResponse
    {
        $context = $this->authorizedCentral($request, 'report.view');

        if (! $context instanceof AdminSessionContext) {
            return $context;
        }

        $errors = $this->validator->reportQueryErrors($request, 'central');

        if ($errors !== []) {
            return ApiErrorResponse::validationFailed($request, $errors);
        }

        $report = $this->growth->report('central', null, $report_key, $request->query());

        return isset($report['error']) ? ApiErrorResponse::notFound($request) : response()->json($report);
    }

    public function tenantReport(Request $request, string $report_key): JsonResponse
    {
        $context = $this->authorizedTenant($request, 'report.view');

        if (! $context instanceof AdminSessionContext) {
            return $context;
        }

        $errors = $this->validator->reportQueryErrors($request, 'tenant');

        if ($errors !== []) {
            return ApiErrorResponse::validationFailed($request, $errors);
        }

        $report = $this->growth->report('tenant', (string) $context->activeTenantId(), $report_key, $request->query());

        return isset($report['error']) ? ApiErrorResponse::notFound($request) : response()->json($report);
    }

    public function createCentralExport(Request $request, string $report_key): JsonResponse
    {
        $context = $this->authorizedCentral($request, 'report.view');

        if (! $context instanceof AdminSessionContext) {
            return $context;
        }

        return $this->writeWithIdempotency(
            $request,
            fn (): array => $this->growth->createReportExport('central', null, $context, $report_key, $request->all(), $request),
            202,
            $this->validator->exportPayloadErrors($request->all(), 'central'),
        );
    }

    public function createTenantExport(Request $request, string $report_key): JsonResponse
    {
        $context = $this->authorizedTenant($request, 'report.view');

        if (! $context instanceof AdminSessionContext) {
            return $context;
        }

        return $this->writeWithIdempotency(
            $request,
            fn (): array => $this->growth->createReportExport('tenant', (string) $context->activeTenantId(), $context, $report_key, $request->all(), $request),
            202,
            $this->validator->exportPayloadErrors($request->all(), 'tenant'),
        );
    }

    public function centralExportJob(Request $request, string $export_job_id): JsonResponse
    {
        $context = $this->authorizedCentral($request, 'report.view');

        if (! $context instanceof AdminSessionContext) {
            return $context;
        }

        $job = $this->growth->exportJob('central', null, $export_job_id);

        return $job === null ? ApiErrorResponse::notFound($request) : response()->json($job);
    }

    public function tenantExportJob(Request $request, string $export_job_id): JsonResponse
    {
        $context = $this->authorizedTenant($request, 'report.view');

        if (! $context instanceof AdminSessionContext) {
            return $context;
        }

        $job = $this->growth->exportJob('tenant', (string) $context->activeTenantId(), $export_job_id);

        return $job === null ? ApiErrorResponse::notFound($request) : response()->json($job);
    }

    public function centralDownload(Request $request, string $export_job_id): JsonResponse|RedirectResponse
    {
        $context = $this->authorizedCentral($request, 'report.view');

        if (! $context instanceof AdminSessionContext) {
            return $context;
        }

        return $this->download($request, 'central', null, $export_job_id);
    }

    public function tenantDownload(Request $request, string $export_job_id): JsonResponse|RedirectResponse
    {
        $context = $this->authorizedTenant($request, 'report.view');

        if (! $context instanceof AdminSessionContext) {
            return $context;
        }

        return $this->download($request, 'tenant', (string) $context->activeTenantId(), $export_job_id);
    }

    private function download(Request $request, string $scope, ?string $tenantId, string $exportJobId): JsonResponse|RedirectResponse
    {
        $result = $this->growth->exportDownloadUrl($scope, $tenantId, $exportJobId);

        return match ($result['error'] ?? null) {
            'not_found' => ApiErrorResponse::notFound($request),
            'resource_conflict' => ApiErrorResponse::resourceConflict($request),
            default => redirect()->away((string) $result['download_url'], 302),
        };
    }

    private function authorizedCentral(Request $request, string $permissionCode): AdminSessionContext|JsonResponse
    {
        $context = $request->attributes->get('admin_session');

        if (! $context instanceof AdminSessionContext) {
            return ApiErrorResponse::authenticationRequired($request);
        }

        if (! $this->permissions->adminHasPermission($context->adminUser['id'], 'central', $context->activeScopeId(), $permissionCode)) {
            return ApiErrorResponse::permissionDenied($request);
        }

        return $context;
    }

    private function authorizedTenant(Request $request, string $permissionCode): AdminSessionContext|JsonResponse
    {
        $context = $request->attributes->get('admin_session');

        if (! $context instanceof AdminSessionContext) {
            return ApiErrorResponse::authenticationRequired($request);
        }

        if (! $this->permissions->adminHasPermission($context->adminUser['id'], 'tenant', $context->activeScopeId(), $permissionCode, $context->activeTenantId())) {
            return ApiErrorResponse::permissionDenied($request);
        }

        return $context;
    }

    /**
     * @param array<string, array<int, string>> $payloadErrors
     */
    private function writeWithIdempotency(Request $request, callable $callback, int $defaultStatus = 200, array $payloadErrors = []): JsonResponse
    {
        $headerErrors = $this->headers->idempotencyKeyErrors($request);

        if ($headerErrors !== []) {
            return ApiErrorResponse::validationFailed($request, $headerErrors);
        }

        if ($payloadErrors !== []) {
            return ApiErrorResponse::validationFailed($request, $payloadErrors);
        }

        $result = $callback();

        return match ($result['error'] ?? null) {
            'idempotency_conflict' => ApiErrorResponse::idempotencyConflict($request),
            'resource_conflict' => ApiErrorResponse::resourceConflict($request),
            'not_found' => ApiErrorResponse::notFound($request),
            'validation_failed' => ApiErrorResponse::validationFailed($request, $result['errors'] ?? ['payload' => ['The request payload is invalid.']]),
            default => response()->json($result['resource'] ?? [], $result['status'] ?? $defaultStatus),
        };
    }
}
