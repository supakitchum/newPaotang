<?php

namespace Tests\Feature;

use App\Models\SupportActor;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\DB;
use Tests\TestCase;

class SupportAssignmentTest extends TestCase
{
    use RefreshDatabase;

    public function test_support_role_cannot_see_tenant_wide_queue_counts_or_queue_list(): void
    {
        $customer = $this->supportToken('customer', 'customer-private-queue');
        $this->withHeaders($this->supportHeaders($customer, 'private-queue-ticket'))
            ->postJson('/v1/customer/tickets', [
                'subject' => 'Private queue ticket',
                'message' => 'Do not expose this queue to unassigned support.',
            ])
            ->assertCreated();

        $agent = $this->supportToken('admin', 'support-private-queue', permissions: [
            'support_ticket.view_assigned',
            'support_ticket.reply_assigned',
        ]);
        $this->withHeaders($this->supportHeaders($agent))
            ->getJson('/v1/admin/bootstrap')
            ->assertOk()
            ->assertJsonPath('counts.mine', 0)
            ->assertJsonPath('counts.queue', 0)
            ->assertJsonPath('counts.all_open', 0)
            ->assertJsonPath('counts.closed', 0);
        $this->withHeaders($this->supportHeaders($agent))
            ->getJson('/v1/admin/tickets?view=queue')
            ->assertForbidden();

        $master = $this->supportToken('admin', 'master-private-queue', permissions: [
            'support_ticket.view_assigned',
            'support_ticket.view_all',
        ]);
        $this->withHeaders($this->supportHeaders($master))
            ->getJson('/v1/admin/bootstrap')
            ->assertOk()
            ->assertJsonPath('counts.queue', 1)
            ->assertJsonPath('counts.all_open', 1);
    }

    public function test_view_all_permission_does_not_grant_management_actions(): void
    {
        $viewer = $this->supportToken('admin', 'support-view-only', permissions: [
            'support_ticket.view_assigned',
            'support_ticket.view_all',
        ]);

        $this->withHeaders($this->supportHeaders($viewer, 'view-only-settings'))
            ->putJson('/v1/admin/settings', [
                'enabled' => true,
                'default_agent_capacity' => 3,
            ])
            ->assertForbidden();
        $this->withHeaders($this->supportHeaders($viewer, 'view-only-available'))
            ->putJson('/v1/admin/agent-state', [
                'available' => true,
                'capacity' => 3,
            ])
            ->assertForbidden();
    }

    public function test_manual_assignment_retry_does_not_duplicate_history_or_system_message(): void
    {
        $customer = $this->supportToken('customer', 'customer-manual-assignment');
        $ticketId = $this->withHeaders($this->supportHeaders($customer, 'manual-ticket'))
            ->postJson('/v1/customer/tickets', [
                'subject' => 'Manual assignment',
                'message' => 'Please assign this ticket',
            ])
            ->assertCreated()
            ->json('ticket.id');

        $agentToken = $this->supportToken('admin', 'support-target', permissions: [
            'support_ticket.view_assigned',
            'support_ticket.reply_assigned',
        ]);
        $this->withHeaders($this->supportHeaders($agentToken))
            ->getJson('/v1/admin/bootstrap')
            ->assertOk();
        $agentId = SupportActor::query()
            ->where('external_id', 'support-target')
            ->value('id');

        $master = $this->supportToken('admin', 'support-master', permissions: [
            'support_ticket.view_all',
            'support_ticket.assign',
            'support_agent.manage',
        ]);
        $headers = $this->supportHeaders($master, 'manual-assign-idempotent');
        $payload = ['admin_actor_id' => $agentId];
        $this->withHeaders($headers)
            ->postJson('/v1/admin/tickets/'.$ticketId.'/assign', $payload)
            ->assertOk()
            ->assertJsonPath('ticket.agent.id', 'support-target');
        $this->withHeaders($headers)
            ->postJson('/v1/admin/tickets/'.$ticketId.'/assign', $payload)
            ->assertOk()
            ->assertJsonPath('ticket.agent.id', 'support-target');
        $this->withHeaders($this->supportHeaders($master, 'manual-assign-same-agent-new-key'))
            ->postJson('/v1/admin/tickets/'.$ticketId.'/assign', $payload)
            ->assertOk()
            ->assertJsonPath('ticket.agent.id', 'support-target');

        $this->assertDatabaseCount('support_assignment_history', 1);
        $this->assertDatabaseCount('support_messages', 3);
        $this->assertDatabaseHas('support_audit_logs', [
            'action' => 'admin.ticket.assign',
            'subject_id' => $ticketId,
        ]);
        $this->assertFalse((bool) DB::table('support_agent_states')
            ->where('admin_actor_id', $agentId)
            ->value('available'));

        $this->withHeaders($this->supportHeaders($agentToken, 'agent-capacity-denied'))
            ->putJson('/v1/admin/agents/'.$agentId.'/state', ['capacity' => 7])
            ->assertForbidden();
        $this->withHeaders($this->supportHeaders($master, 'agent-capacity-managed'))
            ->putJson('/v1/admin/agents/'.$agentId.'/state', ['capacity' => 7])
            ->assertOk()
            ->assertJsonPath('capacity', 7);
        $this->assertSame(7, (int) DB::table('support_agent_states')
            ->where('admin_actor_id', $agentId)
            ->value('capacity'));
        $this->assertDatabaseHas('support_audit_logs', [
            'action' => 'admin.agent_state.manage',
            'subject_id' => $agentId,
        ]);
    }

    public function test_available_agent_receives_fifo_work_up_to_capacity(): void
    {
        $customerOne = $this->supportToken('customer', 'customer-one');
        $firstTicket = $this->withHeaders($this->supportHeaders($customerOne, 'queue-ticket-one'))
            ->postJson('/v1/customer/tickets', [
                'subject' => 'First queued ticket',
                'message' => 'First',
            ])
            ->assertCreated()
            ->json('ticket.id');

        $customerTwo = $this->supportToken('customer', 'customer-two');
        $secondTicket = $this->withHeaders($this->supportHeaders($customerTwo, 'queue-ticket-two'))
            ->postJson('/v1/customer/tickets', [
                'subject' => 'Second queued ticket',
                'message' => 'Second',
            ])
            ->assertCreated()
            ->json('ticket.id');
        DB::table('support_tickets')
            ->where('id', $secondTicket)
            ->update(['priority' => 99]);
        $this->withHeaders($this->supportHeaders($customerTwo))
            ->getJson('/v1/customer/tickets/'.$secondTicket)
            ->assertOk()
            ->assertJsonPath('ticket.queue_position', 2);
        $this->assertDatabaseHas('support_messages', [
            'ticket_id' => $secondTicket,
            'sender_type' => 'system',
            'body' => 'ยินดีต้อนรับสู่ศูนย์ช่วยเหลือ เราได้รับเรื่องของคุณแล้ว ขณะนี้คุณอยู่ในคิวลำดับที่ 2 โปรดรอเจ้าหน้าที่รับงานก่อนเริ่มสนทนา',
        ]);

        $agent = $this->supportToken('admin', 'support-one', permissions: [
            'support_ticket.view_assigned',
            'support_ticket.reply_assigned',
            'support_ticket.close_assigned',
        ]);
        $availableHeaders = $this->supportHeaders($agent, 'agent-available');
        $availability = $this->withHeaders($availableHeaders)
            ->putJson('/v1/admin/agent-state', [
                'available' => true,
                'capacity' => 1,
            ])
            ->assertOk()
            ->assertJsonPath('available', true)
            ->json();
        $this->withHeaders($availableHeaders)
            ->putJson('/v1/admin/agent-state', [
                'available' => true,
                'capacity' => 1,
            ])
            ->assertOk()
            ->assertExactJson($availability);

        $this->assertDatabaseHas('support_tickets', [
            'id' => $firstTicket,
            'status' => 'assigned',
        ]);
        $this->assertDatabaseHas('support_tickets', [
            'id' => $secondTicket,
            'status' => 'queued',
            'assigned_admin_actor_id' => null,
        ]);

        $mine = $this->withHeaders($this->supportHeaders($agent))
            ->getJson('/v1/admin/tickets?view=mine')
            ->assertOk();
        $this->assertSame($firstTicket, $mine->json('data.0.id'));
    }
}
