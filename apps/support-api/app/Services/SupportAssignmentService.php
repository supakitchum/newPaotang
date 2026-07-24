<?php

namespace App\Services;

use App\Models\SupportActor;
use App\Models\SupportAgentState;
use App\Models\SupportMessage;
use App\Models\SupportTicket;
use Illuminate\Support\Facades\Cache;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Str;

class SupportAssignmentService
{
    public function __construct(private readonly SupportBroadcaster $broadcaster)
    {
    }

    public function drainTenant(string $tenantId): int
    {
        $lock = Cache::lock('support-assignment:'.$tenantId, 20);
        if (! $lock->get()) {
            return 0;
        }

        try {
            $assigned = 0;
            while ($ticket = $this->nextQueuedTicket($tenantId)) {
                $agent = $this->nextAgent($tenantId);
                if ($agent === null) {
                    break;
                }
                if ($this->assign($ticket, $agent, 'auto', null)) {
                    $assigned++;
                }
            }

            return $assigned;
        } finally {
            $lock->release();
        }
    }

    public function assign(
        SupportTicket $ticket,
        SupportActor $agent,
        string $assignedByType,
        ?SupportActor $assignedBy,
        ?string $reason = null,
    ): bool {
        $result = DB::transaction(function () use ($ticket, $agent, $assignedByType, $assignedBy, $reason): ?SupportTicket {
            $locked = SupportTicket::query()->whereKey($ticket->id)->lockForUpdate()->first();
            if ($locked === null || $locked->status === 'closed') {
                return null;
            }

            $from = $locked->assigned_admin_actor_id;
            if ($from === $agent->id) {
                return null;
            }
            $locked->fill([
                'assigned_admin_actor_id' => $agent->id,
                'status' => $locked->status === 'queued' ? 'assigned' : $locked->status,
                'assigned_at' => now(),
            ])->save();

            DB::table('support_assignment_history')->insert([
                'id' => 'sah_'.Str::ulid()->toBase32(),
                'tenant_id' => $locked->tenant_id,
                'ticket_id' => $locked->id,
                'from_admin_actor_id' => $from,
                'to_admin_actor_id' => $agent->id,
                'assigned_by_type' => $assignedByType,
                'assigned_by_actor_id' => $assignedBy?->id,
                'reason' => $reason,
                'created_at' => now(),
                'updated_at' => now(),
            ]);

            DB::table('support_agent_states')->upsert([
                [
                    'tenant_id' => $locked->tenant_id,
                    'admin_actor_id' => $agent->id,
                    'available' => $assignedByType === 'auto',
                    'last_assigned_at' => now(),
                    'created_at' => now(),
                    'updated_at' => now(),
                ],
            ], ['tenant_id', 'admin_actor_id'], ['last_assigned_at', 'updated_at']);
            $this->appendSystemMessage($locked, 'เจ้าหน้าที่รับเรื่องแล้ว');

            return $locked->fresh();
        });

        if ($result === null) {
            return false;
        }

        $this->broadcaster->ticketChanged($result, 'support.ticket.assigned', $agent);
        $this->broadcaster->notification($result, 'support.ticket.assigned', [
        ]);

        return true;
    }

    private function nextQueuedTicket(string $tenantId): ?SupportTicket
    {
        return SupportTicket::query()
            ->where('tenant_id', $tenantId)
            ->where('status', 'queued')
            ->orderBy('queued_at')
            ->orderBy('id')
            ->first();
    }

    private function nextAgent(string $tenantId): ?SupportActor
    {
        $cutoff = now()->subSeconds(max(30, (int) config('support.assignment.heartbeat_seconds', 90)));
        $defaultCapacity = (int) DB::table('support_settings')
            ->where('tenant_id', $tenantId)
            ->value('default_agent_capacity') ?: 3;

        $states = SupportAgentState::query()
            ->where('tenant_id', $tenantId)
            ->where('available', true)
            ->where('last_heartbeat_at', '>=', $cutoff)
            ->orderByRaw('last_assigned_at asc nulls first')
            ->get();

        $candidates = [];
        foreach ($states as $state) {
            $actor = SupportActor::query()
                ->whereKey($state->admin_actor_id)
                ->where('actor_type', 'admin')
                ->where('status', 'active')
                ->first();
            if ($actor === null) {
                continue;
            }
            $permissions = is_array($actor->permissions_json) ? $actor->permissions_json : [];
            if (! in_array('support_ticket.reply_assigned', $permissions, true)) {
                continue;
            }
            $activeCount = SupportTicket::query()
                ->where('tenant_id', $tenantId)
                ->where('assigned_admin_actor_id', $actor->id)
                ->whereIn('status', ['assigned', 'in_progress', 'waiting_customer'])
                ->count();
            $capacity = max(1, (int) ($state->capacity ?: $defaultCapacity));
            if ($activeCount < $capacity) {
                $candidates[] = ['actor' => $actor, 'active' => $activeCount, 'last' => $state->last_assigned_at?->getTimestamp() ?? 0];
            }
        }

        usort($candidates, fn (array $a, array $b): int => [$a['active'], $a['last'], $a['actor']->id] <=> [$b['active'], $b['last'], $b['actor']->id]);

        return $candidates[0]['actor'] ?? null;
    }

    private function appendSystemMessage(SupportTicket $ticket, string $body): void
    {
        $ticket->latest_sequence = ((int) $ticket->latest_sequence) + 1;
        $ticket->last_message_preview = $body;
        $ticket->last_message_at = now();
        $ticket->save();
        SupportMessage::query()->create([
            'id' => 'smsg_'.Str::ulid()->toBase32(),
            'tenant_id' => $ticket->tenant_id,
            'ticket_id' => $ticket->id,
            'sequence' => $ticket->latest_sequence,
            'sender_type' => 'system',
            'sender_actor_id' => null,
            'body' => $body,
            'message_type' => 'system',
        ]);
    }
}
