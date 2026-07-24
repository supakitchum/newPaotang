<?php

namespace Tests\Feature;

use App\Models\SupportActor;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Tests\TestCase;

class SupportRealtimeAuthorizationTest extends TestCase
{
    use RefreshDatabase;

    public function test_customer_can_authorize_only_owned_customer_and_ticket_channels(): void
    {
        $owner = $this->supportToken('customer', 'customer-realtime-owner');
        $ticketId = $this->withHeaders($this->supportHeaders($owner, 'realtime-owner-ticket'))
            ->postJson('/v1/customer/tickets', [
                'subject' => 'Realtime ownership',
                'message' => 'Owner message',
            ])
            ->assertCreated()
            ->json('ticket.id');

        $other = $this->supportToken('customer', 'customer-realtime-other');
        $otherTicketId = $this->withHeaders($this->supportHeaders($other, 'realtime-other-ticket'))
            ->postJson('/v1/customer/tickets', [
                'subject' => 'Other realtime ownership',
                'message' => 'Other message',
            ])
            ->assertCreated()
            ->json('ticket.id');

        $prefix = 'private-support.tenant.tenant_test_one.';
        $this->authorize($owner, 'customer', $prefix.'customer.customer-realtime-owner')
            ->assertOk()
            ->assertJsonPath('auth', fn (string $auth): bool => str_starts_with($auth, 'newpaotang-support:'));
        $this->authorize($owner, 'customer', $prefix.'ticket.'.$ticketId)->assertOk();
        $this->authorize($owner, 'customer', $prefix.'customer.customer-realtime-other')->assertForbidden();
        $this->authorize($owner, 'customer', $prefix.'ticket.'.$otherTicketId)->assertForbidden();
        $this->authorize($owner, 'customer', 'private-support.tenant.tenant_other.ticket.'.$ticketId)->assertForbidden();
    }

    public function test_assigned_agent_and_master_receive_only_permitted_channels(): void
    {
        $customer = $this->supportToken('customer', 'customer-realtime-assignment');
        $ticketId = $this->withHeaders($this->supportHeaders($customer, 'realtime-assignment-ticket'))
            ->postJson('/v1/customer/tickets', [
                'subject' => 'Agent realtime assignment',
                'message' => 'Waiting for assignment',
            ])
            ->assertCreated()
            ->json('ticket.id');

        $agent = $this->supportToken('admin', 'support-realtime-agent', permissions: [
            'support_ticket.view_assigned',
            'support_ticket.reply_assigned',
        ]);
        $this->withHeaders($this->supportHeaders($agent))
            ->getJson('/v1/admin/bootstrap')
            ->assertOk();
        $agentId = SupportActor::query()
            ->where('external_id', 'support-realtime-agent')
            ->value('id');

        $master = $this->supportToken('admin', 'support-realtime-master', permissions: [
            'support_ticket.view_assigned',
            'support_ticket.view_all',
            'support_ticket.assign',
        ]);
        $this->withHeaders($this->supportHeaders($master, 'realtime-manual-assignment'))
            ->postJson('/v1/admin/tickets/'.$ticketId.'/assign', [
                'admin_actor_id' => $agentId,
            ])
            ->assertOk();

        $prefix = 'private-support.tenant.tenant_test_one.';
        $this->authorize($agent, 'admin', $prefix.'admin.support-realtime-agent')->assertOk();
        $this->authorize($agent, 'admin', $prefix.'ticket.'.$ticketId)->assertOk();
        $this->authorize($agent, 'admin', $prefix.'queue')->assertForbidden();
        $this->authorize($master, 'admin', $prefix.'queue')->assertOk();
        $this->authorize($master, 'admin', $prefix.'ticket.'.$ticketId)->assertOk();
    }

    private function authorize(
        string $token,
        string $actorType,
        string $channel,
    ): \Illuminate\Testing\TestResponse
    {
        return $this->withHeaders($this->supportHeaders($token))
            ->postJson('/v1/'.$actorType.'/realtime/auth', [
                'socket_id' => '1234.5678',
                'channel_name' => $channel,
            ]);
    }
}
