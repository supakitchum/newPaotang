<?php

namespace App\Http\Controllers;

use App\Auth\SupportActorContext;
use App\Models\SupportTicket;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Routing\Controller;

class SupportRealtimeController extends Controller
{
    public function authorize(Request $request): JsonResponse
    {
        /** @var SupportActorContext $context */
        $context = $request->attributes->get('support_actor');
        $payload = $request->validate([
            'socket_id' => ['required', 'string', 'max:100'],
            'channel_name' => ['required', 'string', 'max:240'],
        ]);
        $channel = (string) $payload['channel_name'];
        abort_unless($this->canAccess($context, $channel), 403);
        $secret = (string) config('reverb.apps.apps.0.secret');
        $signature = hash_hmac('sha256', $payload['socket_id'].':'.$channel, $secret);

        return response()->json([
            'auth' => (string) config('reverb.apps.apps.0.key').':'.$signature,
        ]);
    }

    private function canAccess(SupportActorContext $context, string $channel): bool
    {
        $tenantPrefix = 'private-support.tenant.'.$context->tenantId().'.';
        if (! str_starts_with($channel, $tenantPrefix)) {
            return false;
        }
        $suffix = substr($channel, strlen($tenantPrefix));
        if ($context->isCustomer()) {
            if ($suffix === 'customer.'.$context->externalId()) {
                return true;
            }
            if (! str_starts_with($suffix, 'ticket.')) {
                return false;
            }
            $ticketId = substr($suffix, strlen('ticket.'));

            return SupportTicket::query()
                ->where('tenant_id', $context->tenantId())
                ->where('customer_actor_id', $context->actor->id)
                ->whereKey($ticketId)
                ->exists();
        }
        if ($suffix === 'admin.'.$context->externalId()) {
            return true;
        }
        if ($suffix === 'queue') {
            return $context->hasPermission('support_ticket.view_all');
        }
        if (! str_starts_with($suffix, 'ticket.')) {
            return false;
        }
        $ticketId = substr($suffix, strlen('ticket.'));

        $query = SupportTicket::query()
            ->where('tenant_id', $context->tenantId())
            ->whereKey($ticketId);
        if (! $context->hasPermission('support_ticket.view_all')) {
            $query->where('assigned_admin_actor_id', $context->actor->id);
        }

        return $query->exists();
    }
}
