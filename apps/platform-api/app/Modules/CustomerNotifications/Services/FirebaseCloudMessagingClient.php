<?php

namespace App\Modules\CustomerNotifications\Services;

use Google\Auth\ApplicationDefaultCredentials;
use Illuminate\Support\Facades\Http;

class FirebaseCloudMessagingClient
{
    private const SCOPE = 'https://www.googleapis.com/auth/firebase.messaging';

    /**
     * @param array<string, mixed> $message
     * @return array{ok: bool, message_id?: string, error_code?: string, retryable?: bool}
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

            $status = $response->status();
            $providerStatus = strtoupper(trim((string) $response->json('error.status')));
            $errorCode = match ($providerStatus) {
                'UNREGISTERED' => 'unregistered',
                'INVALID_ARGUMENT' => 'invalid_argument',
                'QUOTA_EXCEEDED', 'RESOURCE_EXHAUSTED' => 'quota_exceeded',
                'UNAVAILABLE' => 'provider_unavailable',
                'UNAUTHENTICATED', 'PERMISSION_DENIED' => 'provider_auth_failed',
                default => 'provider_error',
            };

            return [
                'ok' => false,
                'error_code' => $errorCode,
                'retryable' => $status === 429 || $status >= 500,
            ];
        } catch (\Throwable) {
            return ['ok' => false, 'error_code' => 'provider_unavailable', 'retryable' => true];
        }
    }
}
