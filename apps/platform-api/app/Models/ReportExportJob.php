<?php

namespace App\Models;

use App\Models\Concerns\BelongsToTenant;
use Illuminate\Database\Eloquent\Relations\BelongsTo;

class ReportExportJob extends BaseModel
{
    use BelongsToTenant;

    protected $table = 'report_export_jobs';

    protected $fillable = [
        'id',
        'scope',
        'tenant_id',
        'requested_by_admin_id',
        'source',
        'report_key',
        'format',
        'status',
        'download_url',
        'error_code',
        'expires_at',
        'idempotency_key',
        'payload_hash',
        'filters_json',
        'created_at',
        'updated_at',
    ];

    protected $casts = [
        'progress_percent' => 'integer',
        'expires_at' => 'datetime',
        'filters_json' => 'array',
    ];

    public function requestedByAdmin(): BelongsTo
    {
        return $this->belongsTo(AdminUser::class, 'requested_by_admin_id');
    }
}
