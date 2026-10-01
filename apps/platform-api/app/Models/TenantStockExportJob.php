<?php

namespace App\Models;

use App\Models\Concerns\BelongsToTenant;
use Illuminate\Database\Eloquent\Relations\BelongsTo;

class TenantStockExportJob extends BaseModel
{
    use BelongsToTenant;

    protected $table = 'tenant_stock_export_jobs';

    protected $fillable = [
        'id',
        'tenant_id',
        'status',
        'idempotency_key',
        'payload_hash',
        'requested_by_admin_id',
        'payload_json',
        'created_at',
        'updated_at',
    ];

    protected $casts = [
        'payload_json' => 'array',
    ];

    public function requestedByAdmin(): BelongsTo
    {
        return $this->belongsTo(AdminUser::class, 'requested_by_admin_id');
    }
}
