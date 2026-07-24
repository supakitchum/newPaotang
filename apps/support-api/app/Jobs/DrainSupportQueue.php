<?php

namespace App\Jobs;

use App\Models\SupportTenant;
use App\Services\SupportAssignmentService;
use Illuminate\Contracts\Queue\ShouldQueue;
use Illuminate\Foundation\Queue\Queueable;

class DrainSupportQueue implements ShouldQueue
{
    use Queueable;

    public int $tries = 3;

    public int $timeout = 60;

    public function handle(SupportAssignmentService $assignments): void
    {
        SupportTenant::query()
            ->where('enabled', true)
            ->orderBy('id')
            ->pluck('id')
            ->each(fn (string $tenantId): int => $assignments->drainTenant($tenantId));
    }
}
