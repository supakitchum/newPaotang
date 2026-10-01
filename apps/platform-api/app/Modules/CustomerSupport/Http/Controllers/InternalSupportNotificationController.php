<?php

namespace App\Modules\CustomerSupport\Http\Controllers;

use App\Modules\CustomerNotifications\Services\CustomerNotificationService;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Routing\Controller;

class InternalSupportNotificationController extends Controller
{
    public function __construct(private readonly CustomerNotificationService $notifications)
    {
    }

    public function store(Request $request): JsonResponse
    {
        $secret = trim((string) config('support.ingress_secret'));
        $signature = trim((string) $request->header('X-Support-Signature'));
        $body = (string) $request->getContent();
        if ($secret === '' || $signature === '' || ! hash_equals(hash_hmac('sha256', $body, $secret), $signature)) {
            return response()->json(['error' => ['code' => 'invalid_signature']], 401);
        }
        $payload = $request->validate([
            'tenant_id' => ['required', 'string', 'max:30'],
            'customer_id' => ['required', 'string', 'max:30'],
            'ticket_id' => ['required', 'string', 'max:30'],
            'ticket_no' => ['required', 'string', 'max:32'],
            'event_key' => ['required', 'string', 'max:120'],
            'title' => [
                'required',
                static function (string $attribute, mixed $value, \Closure $fail): void {
                    if (! is_string($value) && ! is_array($value)) {
                        $fail($attribute.' must be localized content.');
                    }
                },
            ],
            'title.*' => ['string', 'max:160'],
            'body' => [
                'required',
                static function (string $attribute, mixed $value, \Closure $fail): void {
                    if (! is_string($value) && ! is_array($value)) {
                        $fail($attribute.' must be localized content.');
                    }
                },
            ],
            'body.*' => ['string', 'max:500'],
            'message_id' => ['nullable', 'string', 'max:40'],
        ]);
        $resource = $this->notifications->createForCustomer(
            (string) $payload['tenant_id'],
            (string) $payload['customer_id'],
            (string) $payload['event_key'],
            [
                'category' => 'support',
                'title' => is_array($payload['title'])
                    ? $payload['title']
                    : ['th-TH' => (string) $payload['title']],
                'body' => is_array($payload['body'])
                    ? $payload['body']
                    : ['th-TH' => (string) $payload['body']],
                'icon_key' => 'headset',
                'action_key' => 'support_ticket',
                'action_entity_id' => (string) $payload['ticket_id'],
                'subject_type' => 'support_ticket',
                'subject_id' => (string) $payload['ticket_id'],
            ],
            [
                'dedupe_key' => (string) $request->header('X-Support-Event-Id', $payload['event_key'].':'.$payload['ticket_id']),
                'creator_type' => 'support_service',
                'metadata' => [
                    'ticket_no' => (string) $payload['ticket_no'],
                    'message_id' => $payload['message_id'] ?? null,
                ],
            ],
        );

        return $resource === null
            ? response()->json(['error' => ['code' => 'customer_not_found']], 404)
            : response()->json(['notification' => $resource], 201);
    }
}
