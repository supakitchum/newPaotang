<?php

namespace App\Modules\Auth\Services;

use App\Shared\Auth\CustomerSessionContext;

class CustomerRealtimeAuthService
{
    /**
     * @param array<string, mixed> $payload
     * @return array<string, array<int, string>>
     */
    public function validationErrors(array $payload): array
    {
        $errors = [];

        foreach (['socket_id', 'channel_name'] as $field) {
            if (! array_key_exists($field, $payload) || ! is_string($payload[$field]) || trim($payload[$field]) === '') {
                $errors[$field][] = 'The '.$field.' field is required.';
            }
        }

        if (array_key_exists('socket_id', $payload) && is_string($payload['socket_id']) && strlen($payload['socket_id']) > 120) {
            $errors['socket_id'][] = 'The socket_id field must not exceed 120 characters.';
        }

        if (array_key_exists('channel_name', $payload) && is_string($payload['channel_name']) && strlen($payload['channel_name']) > 200) {
            $errors['channel_name'][] = 'The channel_name field must not exceed 200 characters.';
        }

        return $errors;
    }

    /**
     * @param array<string, mixed> $payload
     * @return array<string, mixed>|null
     */
    public function authorize(CustomerSessionContext $context, array $payload): ?array
    {
        $socketId = trim((string) $payload['socket_id']);
        $channelName = trim((string) $payload['channel_name']);

        if (! $this->isAllowedChannel($context, $channelName)) {
            return null;
        }

        $channelData = null;
        $stringToSign = $socketId.':'.$channelName;

        if (str_starts_with($channelName, 'presence-')) {
            $channelData = json_encode([
                'user_id' => $context->customerId(),
                'user_info' => [
                    'name' => $context->customer['name'] ?? null,
                    'tenant_id' => $context->tenantId(),
                    'customer_id' => $context->customerId(),
                ],
            ], JSON_THROW_ON_ERROR);

            $stringToSign .= ':'.$channelData;
        }

        $key = trim((string) config('broadcasting.connections.reverb.key', ''));
        $secret = trim((string) config('broadcasting.connections.reverb.secret', ''));

        if ($key === '') {
            $key = 'newpaotang-admin';
        }

        if ($secret === '') {
            $secret = 'newpaotang-admin-secret';
        }

        return [
            'auth' => $key.':'.hash_hmac('sha256', $stringToSign, $secret),
            'channel_data' => $channelData,
            'expires_at' => now()->addSeconds((int) config('platform.realtime.auth_ttl_seconds', 300))->toISOString(),
        ];
    }

    private function isAllowedChannel(CustomerSessionContext $context, string $channelName): bool
    {
        $tenantId = $context->tenantId();
        $customerId = $context->customerId();

        return in_array($channelName, [
            'private-customer.tenant.'.$tenantId.'.customer.'.$customerId,
            'private-customer.tenant.'.$tenantId.'.customer.'.$customerId.'.cart',
            'private-customer.tenant.'.$tenantId.'.customer.'.$customerId.'.orders',
            'private-customer.tenant.'.$tenantId.'.customer.'.$customerId.'.tickets',
            'private-customer.tenant.'.$tenantId.'.customer.'.$customerId.'.topups',
            'private-customer.tenant.'.$tenantId.'.customer.'.$customerId.'.wallet',
            'private-customer.tenant.'.$tenantId.'.customer.'.$customerId.'.reward-claims',
            'private-customer.tenant.'.$tenantId.'.customer.'.$customerId.'.activity-claims',
            'presence-customer.tenant.'.$tenantId.'.customers',
        ], true) || preg_match('/^private-customer\.tenant\.'.preg_quote($tenantId, '/').'\.stock\.game\.[A-Za-z0-9_-]+$/', $channelName) === 1;
    }
}
