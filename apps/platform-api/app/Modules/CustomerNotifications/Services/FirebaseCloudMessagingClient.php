<?php

namespace App\Modules\CustomerNotifications\Services;

use Google\Auth\ApplicationDefaultCredentials;
use Illuminate\Support\Facades\Http;

class FirebaseCloudMessagingClient
{
    private const SCOPE = 'https://www.googleapis.com/auth/firebase.messaging';

    /**
     * @param array<string, mixed> $message
     * @return array{ok: bool, message_id?: string, error_code?: string, retryable?: bool, revoke_device?: bool}
     */
    public function send(array $message): array
    {
        $projectId = trim((string) config('services.firebase_cloud_messaging.project_id', ''));

        if ($projectId === '' || ! class_exists(ApplicationDefaultCredentials::class)) {
            return ['ok' => false, 'error_code' => 'provider_unavailable', 'retryable' => false];
        }

        try {
            $credentials = ApplicationDefaultCredentials::getCredentials(self::SCOPE);
            $auth = $credentials->fetchAuthToken();
            $accessToken = trim((string) ($auth['access_token'] ?? ''));

            if ($accessToken === '') {
                return ['ok' => false, 'error_code' => 'provider_auth_failed', 'retryable' => true];
            }

            $endpoint = rtrim((string) config('services.firebase_cloud_messaging.endpoint', 'https://fcm.googleapis.com/v1'), '/');
            $response = Http::acceptJson()
                ->withToken($accessToken)
                ->timeout((int) config('services.firebase_cloud_messaging.timeout', 15))
                ->post($endpoint.'/projects/'.rawurlencode($projectId).'/messages:send', [
                    'message' => $message,
                ]);

            if ($response->successful()) {
                return [
                    'ok' => true,
                    'message_id' => trim((string) $response->json('name')),
                ];
            }

            return ['ok' => false, ...self::classifyFailure(
                $response->status(),
                is_array($response->json('error')) ? $response->json('error') : [],
            )];
        } catch (\Throwable) {
            return ['ok' => false, 'error_code' => 'provider_unavailable', 'retryable' => true];
        }
    }

    /**
     * Separate payload validation failures from token-specific FCM failures.
     * A generic HTTP INVALID_ARGUMENT must not revoke an otherwise valid token.
     *
     * @param array<string, mixed> $error
     * @return array{error_code: string, retryable: bool, revoke_device: bool}
     */
    public static function classifyFailure(int $httpStatus, array $error): array
    {
        $providerStatus = strtoupper(trim((string) ($error['status'] ?? '')));
        $fcmErrorCode = '';

        foreach (is_array($error['details'] ?? null) ? $error['details'] : [] as $detail) {
            if (! is_array($detail)) {
                continue;
            }

            $type = strtolower(trim((string) ($detail['@type'] ?? '')));
            if (str_contains($type, 'google.firebase.fcm.v1.fcmerror')) {
                $fcmErrorCode = strtoupper(trim((string) ($detail['errorCode'] ?? $detail['error_code'] ?? '')));
                break;
            }
        }

        $revokeDevice = $providerStatus === 'UNREGISTERED'
            || in_array($fcmErrorCode, ['UNREGISTERED', 'INVALID_ARGUMENT'], true);
        $errorCode = match (true) {
            $providerStatus === 'UNREGISTERED', $fcmErrorCode === 'UNREGISTERED' => 'unregistered',
            $fcmErrorCode === 'INVALID_ARGUMENT' => 'invalid_argument',
            $providerStatus === 'INVALID_ARGUMENT' => 'invalid_payload',
            in_array($providerStatus, ['QUOTA_EXCEEDED', 'RESOURCE_EXHAUSTED'], true) => 'quota_exceeded',
            $providerStatus === 'UNAVAILABLE' => 'provider_unavailable',
            in_array($providerStatus, ['UNAUTHENTICATED', 'PERMISSION_DENIED'], true) => 'provider_auth_failed',
            default => 'provider_error',
        };

        return [
            'error_code' => $errorCode,
            'retryable' => $httpStatus === 429 || $httpStatus >= 500,
            'revoke_device' => $revokeDevice,
        ];
    }
}
