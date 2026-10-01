<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Relations\BelongsTo;

class StockAllocationJobItem extends BaseModel
{
    protected $fillable = [
        'id',
        'job_id',
        'partner_id',
        'tenant_id',
        'allocation_id',
        'status',
        'percent_basis_points',
        'target_count',
        'message',
        'error_message',
        'created_at',
        'updated_at',
    ];

    protected $casts = [
        'percent_basis_points' => 'integer',
        'target_count' => 'integer',
    ];

    public function job(): BelongsTo
    {
        return $this->belongsTo(StockAllocationJob::class, 'job_id');
    }
}
