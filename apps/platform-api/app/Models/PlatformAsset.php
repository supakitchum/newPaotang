<?php

namespace App\Models;

use App\Models\Concerns\BelongsToTenant;
use Illuminate\Database\Eloquent\Relations\BelongsTo;

class PlatformAsset extends BaseModel
{
    use BelongsToTenant;

    protected $table = 'platform_assets';

    protected $fillable = [
        'id',
        'scope_type',
        'tenant_id',
        'created_by_admin_id',
        'purpose',
        'file_name',
        'content_type',
        'size_bytes',
        'checksum_sha256',
        'status',
        'storage_key',
        'upload_url',
        'public_url',
        'metadata_json',
        'expires_at',
        'committed_at',
        'created_at',
        'updated_at',
    ];

    protected $casts = [
        'size_bytes' => 'integer',
        'metadata_json' => 'array',
        'expires_at' => 'datetime',
        'committed_at' => 'datetime',
    ];

    public function createdByAdmin(): BelongsTo
    {
        return $this->belongsTo(AdminUser::class, 'created_by_admin_id');
    }
}
