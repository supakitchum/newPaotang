<?php

namespace App\Models;

use App\Models\Concerns\BelongsToTenant;
use Illuminate\Database\Eloquent\Relations\BelongsTo;

class SupportAccessApproval extends BaseModel
{
    use BelongsToTenant;

    protected $table = 'support_access_approvals';

    protected $fillable = [
        'id',
        'tenant_id',
        'support_access_request_id',
        'action',
        'status',
        'reason',
        'actor_admin_id',
        'metadata_json',
        'created_at',
        'updated_at',
    ];

    protected $casts = [
        'metadata_json' => 'array',
    ];

    public function supportAccessRequest(): BelongsTo
    {
        return $this->belongsTo(SupportAccessRequest::class, 'support_access_request_id');
    }

    public function actorAdmin(): BelongsTo
    {
        return $this->belongsTo(AdminUser::class, 'actor_admin_id');
    }
}
