<?php

namespace App\Modules\TelegramNotifications\Services;

use Illuminate\Support\Facades\Http;

class TelegramBotClient
{
    public function getMe(string $botToken): array
    {
        return $this->post($botToken, 'getMe');
    }

    public function getUpdates(string $botToken, ?int $offset = null): array
    {
        $payload = [
            'timeout' => 0,
            'limit' => 100,
            'allowed_updates' => ['message', 'edited_message', 'channel_post', 'edited_channel_post'],
        ];

        if ($offset !== null) {
            $payload['offset'] = $offset;
        }

        return $this->post($botToken, 'getUpdates', $payload);
    }

    public function sendMessage(string $botToken, string $chatId, string $text): array
    {
        return $this->post($botToken, 'sendMessage', [
            'chat_id' => $chatId,
            'text' => $text,
            'parse_mode' => 'HTML',
            'disable_web_page_preview' => true,
        ]);
    }

    private function post(string $botToken, string $method, array $payload = []): array
    {
        $response = Http::acceptJson()
            ->asJson()
            ->timeout(10)
            ->post('https://api.telegram.org/bot'.$botToken.'/'.$method, $payload);

        $body = $response->json();
        $data = is_array($body) ? $body : [];

        if (! $response->successful() || ($data['ok'] ?? false) !== true) {
            return [
                'ok' => false,
                'status' => $response->status(),
                'message' => (string) ($data['description'] ?? $response->body()),
                'data' => $data,
            ];
        }

        return [
            'ok' => true,
            'status' => $response->status(),
            'data' => $data['result'] ?? [],
        ];
    }
}
