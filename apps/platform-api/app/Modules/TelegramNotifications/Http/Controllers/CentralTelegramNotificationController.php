<?php

namespace App\Modules\TelegramNotifications\Http\Controllers;

use App\Modules\Rbac\Services\PermissionService;
use App\Modules\TelegramNotifications\Services\CentralTelegramNotificationService;
use App\Shared\Auth\AdminSessionContext;
use App\Shared\Auth\ApiErrorResponse;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Routing\Controller;

class CentralTelegramNotificationController extends Controller
{
    public function __construct(
        private readonly PermissionService $permissions,
        private readonly CentralTelegramNotificationService $notifications,
    ) {
    }

    public function show(Request $request): JsonResponse
    {
        $context = $this->centralContext($request, 'telegram_notification.view');

        return $context instanceof AdminSessionContext
            ? response()->json($this->notifications->show())
            : $context;
    }

    public function updateBot(Request $request): JsonResponse
    {
        $context = $this->centralContext($request, 'telegram_notification.manage');

        return $context instanceof AdminSessionContext
            ? $this->writeResult($request, $this->notifications->updateBot($request->all()))
            : $context;
    }

    public function disconnectBot(Request $request): JsonResponse
    {
        $context = $this->centralContext($request, 'telegram_notification.manage');

        return $context instanceof AdminSessionContext
            ? $this->writeResult($request, $this->notifications->disconnectBot())
            : $context;
    }

    public function syncChats(Request $request): JsonResponse
    {
        $context = $this->centralContext($request, 'telegram_notification.manage');

        return $context instanceof AdminSessionContext
            ? $this->writeResult($request, $this->notifications->syncChats())
            : $context;
    }

    public function chats(Request $request): JsonResponse
    {
        $context = $this->centralContext($request, 'telegram_notification.view');

        return $context instanceof AdminSessionContext
            ? response()->json($this->notifications->chats($request->query()))
            : $context;
    }

    public function testSend(Request $request): JsonResponse
    {
        $context = $this->centralContext($request, 'telegram_notification.manage');

        return $context instanceof AdminSessionContext
            ? $this->writeResult($request, $this->notifications->testSend($request->all()))
            : $context;
    }

    public function routes(Request $request): JsonResponse
    {
        $context = $this->centralContext($request, 'telegram_notification.view');

        return $context instanceof AdminSessionContext
            ? response()->json($this->notifications->routes())
            : $context;
    }

    public function updateRoutes(Request $request): JsonResponse
    {
        $context = $this->centralContext($request, 'telegram_notification.manage');

        return $context instanceof AdminSessionContext
            ? $this->writeResult($request, $this->notifications->updateRoutes($request->all()))
            : $context;
    }

    public function templates(Request $request): JsonResponse
    {
        $context = $this->centralContext($request, 'telegram_notification.view');

        return $context instanceof AdminSessionContext
            ? response()->json(['data' => $this->notifications->templates()])
            : $context;
    }

    public function updateTemplate(Request $request, string $event_key): JsonResponse
    {
        $context = $this->centralContext($request, 'telegram_notification.manage');

        return $context instanceof AdminSessionContext
            ? $this->writeResult($request, $this->notifications->updateTemplate($event_key, $request->all()))
            : $context;
    }

    public function deliveries(Request $request): JsonResponse
    {
        $context = $this->centralContext($request, 'telegram_notification.view');

        return $context instanceof AdminSessionContext
            ? response()->json($this->notifications->deliveries($request->query()))
            : $context;
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
        if (($result['error'] ?? null) === 'validation_failed' || ($result['error'] ?? null) === 'telegram_verification_failed') {
            return ApiErrorResponse::validationFailed($request, $result['errors'] ?? ['payload' => ['The request payload is invalid.']]);
        }

        if (in_array(($result['error'] ?? null), ['telegram_encryption_not_configured', 'telegram_encryption_failed', 'telegram_bot_not_ready', 'telegram_sync_failed', 'telegram_test_send_failed'], true)) {
            return ApiErrorResponse::make(
                $request,
                503,
                (string) $result['error'],
                (string) ($result['message'] ?? 'เกิดข้อผิดพลาดในการเชื่อมต่อ Telegram กรุณาตรวจสอบข้อมูลแล้วลองใหม่อีกครั้ง'),
                $result['details'] ?? [],
            );
        }

        if (($result['error'] ?? null) === 'not_found') {
            return ApiErrorResponse::notFound($request);
        }

        return response()->json($result['resource'] ?? []);
    }
}
