<?php

namespace App\Services;

use App\Models\SupportTicket;

class SupportQueueService
{
    public function position(SupportTicket $ticket): ?int
    {
        if ($ticket->status !== 'queued') {
            return null;
        }

        return SupportTicket::query()
            ->where('tenant_id', $ticket->tenant_id)
            ->where('status', 'queued')
            ->where(function ($query) use ($ticket): void {
                $query->where('queued_at', '<', $ticket->queued_at)
                    ->orWhere(function ($sameTime) use ($ticket): void {
                        $sameTime->where('queued_at', $ticket->queued_at)
                            ->where('id', '<', $ticket->id);
                    });
            })
            ->count() + 1;
    }
}
