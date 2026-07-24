<?php

namespace Tests\Feature;

use App\Models\SupportActor;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\DB;
use Tests\TestCase;

class SupportReportsTest extends TestCase
{
    use RefreshDatabase;

    public function test_support_sees_only_personal_report_while_master_can_view_team_and_agent_reports(): void
    {
        $agentToken = $this->supportToken('admin', 'support-report-agent', permissions: [
            'support_ticket.view_assigned',
            'support_ticket.reply_assigned',
        ], overrides: ['name' => 'Agent One']);
        $this->withHeaders($this->supportHeaders($agentToken))
            ->getJson('/v1/admin/bootstrap')
            ->assertOk();
        $agent = SupportActor::query()
            ->where('external_id', 'support-report-agent')
            ->firstOrFail();

        $customerToken = $this->supportToken('customer', 'support-report-customer');
        $ticketId = $this->withHeaders($this->supportHeaders($customerToken, 'report-ticket'))
            ->postJson('/v1/customer/tickets', [
                'subject' => 'Report ticket',
                'message' => 'Please help with this report test.',
            ])
            ->assertCreated()
            ->json('ticket.id');
        $customer = SupportActor::query()
            ->where('external_id', 'support-report-customer')
            ->firstOrFail();
        $createdAt = now()->subDay();
        DB::table('support_tickets')->where('id', $ticketId)->update([
            'assigned_admin_actor_id' => $agent->id,
            'status' => 'closed',
            'active_slot' => null,
            'created_at' => $createdAt,
            'first_response_at' => $createdAt->copy()->addMinutes(5),
            'closed_at' => $createdAt->copy()->addHour(),
            'updated_at' => now(),
        ]);
        DB::table('support_ratings')->insert([
            'id' => 'srat_report_agent',
            'tenant_id' => 'tenant_test_one',
            'ticket_id' => $ticketId,
            'customer_actor_id' => $customer->id,
            'stars' => 5,
            'comment' => 'Very helpful',
            'created_at' => now(),
            'updated_at' => now(),
        ]);

        $this->withHeaders($this->supportHeaders($agentToken))
            ->getJson('/v1/admin/reports?days=30&actor_id=another-agent')
            ->assertOk()
            ->assertJsonPath('scope', 'self')
            ->assertJsonPath('can_view_team', false)
            ->assertJsonPath('actor.id', $agent->id)
            ->assertJsonPath('tickets_assigned', 1)
            ->assertJsonPath('tickets_closed', 1)
            ->assertJsonPath('average_first_response_seconds', 300)
            ->assertJsonPath('average_rating', 5)
            ->assertJsonCount(0, 'agents')
            ->assertJsonCount(0, 'agent_reports');

        $masterToken = $this->supportToken('admin', 'support-report-master', permissions: [
            'support_ticket.view_assigned',
            'support_ticket.view_all',
            'support_report.view',
        ], overrides: ['name' => 'Master Support']);
        $this->withHeaders($this->supportHeaders($masterToken))
            ->getJson('/v1/admin/reports?days=30')
            ->assertOk()
            ->assertJsonPath('scope', 'overview')
            ->assertJsonPath('can_view_team', true)
            ->assertJsonPath('tickets_opened', 1)
            ->assertJsonPath('agent_reports.0.actor.id', $agent->id)
            ->assertJsonPath('agent_reports.0.tickets_closed', 1);

        $this->withHeaders($this->supportHeaders($masterToken))
            ->getJson('/v1/admin/reports?days=30&actor_id='.$agent->id)
            ->assertOk()
            ->assertJsonPath('scope', 'agent')
            ->assertJsonPath('actor.name', 'Agent One')
            ->assertJsonPath('tickets_assigned', 1)
            ->assertJsonPath('average_rating', 5);
    }
}
