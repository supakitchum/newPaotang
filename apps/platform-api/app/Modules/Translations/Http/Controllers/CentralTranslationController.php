<?php

namespace App\Modules\Translations\Http\Controllers;

use App\Modules\Rbac\Services\PermissionService;
use App\Modules\Translations\Services\SystemTranslationService;
use App\Shared\Auth\AdminSessionContext;
use App\Shared\Auth\ApiErrorResponse;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Routing\Controller;

class CentralTranslationController extends Controller
{
    public function __construct(
        private readonly PermissionService $permissions,
        private readonly SystemTranslationService $translations,
    ) {
    }

    public function languages(Request $request): JsonResponse
    {
        $context = $this->centralContext($request, 'translation.view');

        return $context instanceof AdminSessionContext
            ? response()->json($this->translations->languages())
            : $context;
    }

    public function upsertLanguage(Request $request): JsonResponse
    {
        $context = $this->centralContext($request, 'translation.edit');

        return $context instanceof AdminSessionContext
            ? $this->writeResult($request, $this->translations->upsertLanguage($request->all()))
            : $context;
    }

    public function keys(Request $request): JsonResponse
    {
        $context = $this->centralContext($request, 'translation.view');

        return $context instanceof AdminSessionContext
            ? response()->json($this->translations->keys($request->query()))
            : $context;
    }

    public function saveDraft(Request $request, string $key_id): JsonResponse
    {
        $context = $this->centralContext($request, 'translation.edit');

        return $context instanceof AdminSessionContext
            ? $this->writeResult($request, $this->translations->saveDraft($key_id, $request->all(), $context->adminUser['id']))
            : $context;
    }

    public function deployRequests(Request $request): JsonResponse
    {
        $context = $this->centralContext($request, 'translation.view');

        return $context instanceof AdminSessionContext
            ? response()->json($this->translations->deployRequests($request->query()))
            : $context;
    }

    public function createDeployRequest(Request $request): JsonResponse
    {
        $context = $this->centralContext($request, 'translation.request_deploy');

        return $context instanceof AdminSessionContext
            ? $this->writeResult($request, $this->translations->createDeployRequest($request->all(), $context->adminUser['id']))
            : $context;
    }

    public function submitDeployRequest(Request $request, string $id): JsonResponse
    {
        $context = $this->centralContext($request, 'translation.request_deploy');

        return $context instanceof AdminSessionContext
            ? $this->writeResult($request, $this->translations->submitDeployRequest($id, $context->adminUser['id']))
            : $context;
    }

    public function cancelDeployRequest(Request $request, string $id): JsonResponse
    {
        $context = $this->centralContext($request, 'translation.request_deploy');

        return $context instanceof AdminSessionContext
            ? $this->writeResult($request, $this->translations->cancelDeployRequest($id))
            : $context;
    }

    public function previewSession(Request $request, string $id): JsonResponse
    {
        $context = $this->centralContext($request, 'translation.approve_deploy');

        return $context instanceof AdminSessionContext
            ? $this->writeResult($request, $this->translations->previewSession($id, $context->adminUser['id']))
            : $context;
    }

    public function approve(Request $request, string $id): JsonResponse
    {
        $context = $this->centralContext($request, 'translation.approve_deploy');

        return $context instanceof AdminSessionContext
            ? $this->writeResult($request, $this->translations->approveDeployRequest($id, $context->adminUser['id']))
            : $context;
    }

    public function reject(Request $request, string $id): JsonResponse
    {
        $context = $this->centralContext($request, 'translation.approve_deploy');

        return $context instanceof AdminSessionContext
            ? $this->writeResult($request, $this->translations->rejectDeployRequest($id, $context->adminUser['id'], $request->all()))
            : $context;
    }

    public function runtime(Request $request): JsonResponse
    {
        $context = $request->attributes->get('admin_session');
        if (! $context instanceof AdminSessionContext) {
            return ApiErrorResponse::authenticationRequired($request);
        }

        return $this->bundleResponse($request, 'back-office');
    }

    private function centralContext(Request $request, string $permissionCode): AdminSessionContext|JsonResponse
    {
        $context = $request->attributes->get('admin_session');

        if (! $context instanceof AdminSessionContext) {
            return ApiErrorResponse::authenticationRequired($request);
        }

        if ($context->activeScope() !== 'central') {
            return ApiErrorResponse::permissionDenied($request);
        }

        if (! $this->permissions->adminHasPermission(
            $context->adminUser['id'],
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

        if (($result['error'] ?? null) === 'not_found') {
            return ApiErrorResponse::notFound($request);
        }

        return response()->json($result['resource'] ?? $result);
    }

    private function bundleResponse(Request $request, string $defaultSurface): JsonResponse
    {
        $locale = $request->query('locale') ?: $request->header('X-Locale') ?: $request->header('Accept-Language');
        $surface = $request->query('surface') ?: $defaultSurface;
        $previewToken = $request->query('preview_token') ?: $request->header('X-Translation-Preview');
        $bundle = $this->translations->runtimeBundle(is_string($locale) ? $locale : null, is_string($surface) ? $surface : null, is_string($previewToken) ? $previewToken : null);

        return response()
            ->json($bundle)
            ->header('Content-Language', $bundle['locale'])
            ->header('Vary', 'Accept-Language');
    }
}
