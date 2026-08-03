<?php

namespace App\Modules\LineNotifications\Services;

use Illuminate\Support\Facades\Http;

class LineMessagingClient
{
    public function botInfo(string $channelAccessToken): array
    {
        $response = Http::acceptJson()
            ->withToken($channelAccessToken)
            ->timeout(10)
            ->get('https://api.line.me/v2/bot/info');

        if (! $response->successful()) {
            return [
                'ok' => false,
                'status' => $response->status(),
                'message' => $response->body(),
            ];
        }

        return [
            'ok' => true,
            'data' => $response->json() ?: [],
        ];
    }

    public function verifyMessagingToken(string $channelAccessToken): array
    {
        $response = Http::asForm()
            ->acceptJson()
            ->timeout(10)
            ->post('https://api.line.me/v2/oauth/verify', [
                'access_token' => $channelAccessToken,
            ]);

        if (! $response->successful()) {
            return [
                'ok' => false,
                'status' => $response->status(),
                'message' => $response->body(),
            ];
        }

        return [
            'ok' => true,
            'data' => $response->json() ?: [],
        ];
    }

    public function exchangeLoginCode(string $channelId, string $channelSecret, string $code, string $redirectUri): array
    {
        $response = Http::asForm()
            ->acceptJson()
            ->timeout(10)
            ->post('https://api.line.me/oauth2/v2.1/token', [
                'grant_type' => 'authorization_code',
                'code' => $code,
                'redirect_uri' => $redirectUri,
                'client_id' => $channelId,
                'client_secret' => $channelSecret,
            ]);

        if (! $response->successful()) {
            return [
                'ok' => false,
                'status' => $response->status(),
                'message' => $response->body(),
            ];
        }

        return [
            'ok' => true,
            'data' => $response->json() ?: [],
        ];
    }

    public function verifyLoginAccessToken(string $accessToken): array
    {
        $response = Http::acceptJson()
            ->timeout(10)
            ->get('https://api.line.me/oauth2/v2.1/verify', [
                'access_token' => $accessToken,
            ]);

        if (! $response->successful()) {
            return [
                'ok' => false,
                'status' => $response->status(),
                'message' => $response->body(),
            ];
        }

        return [
            'ok' => true,
            'data' => $response->json() ?: [],
        ];
    }

    public function profile(string $accessToken): array
    {
        $response = Http::acceptJson()
            ->withToken($accessToken)
            ->timeout(10)
            ->get('https://api.line.me/v2/profile');

        if (! $response->successful()) {
            return [
                'ok' => false,
                'status' => $response->status(),
                'message' => $response->body(),
            ];
        }

        return [
            'ok' => true,
            'data' => $response->json() ?: [],
        ];
    }

    public function friendshipStatus(string $accessToken): array
    {
        $response = Http::acceptJson()
            ->withToken($accessToken)
            ->timeout(10)
            ->get('https://api.line.me/friendship/v1/status');

        if (! $response->successful()) {
            return [
                'ok' => false,
                'status' => $response->status(),
                'message' => $response->body(),
            ];
        }

        return [
            'ok' => true,
            'data' => $response->json() ?: [],
        ];
    }

    public function push(string $channelAccessToken, string $lineUserId, array $messages, string $retryKey): array
    {
        $response = Http::acceptJson()
            ->withHeaders(['X-Line-Retry-Key' => $retryKey])
            ->withToken($channelAccessToken)
            ->timeout(10)
            ->post('https://api.line.me/v2/bot/message/push', [
                'to' => $lineUserId,
                'messages' => array_slice($messages, 0, 5),
            ]);

        if (! $response->successful()) {
            return [
                'ok' => false,
                'status' => $response->status(),
                'message' => $response->body(),
            ];
        }

        return [
            'ok' => true,
            'data' => $response->json() ?: [],
        ];
    }
}
