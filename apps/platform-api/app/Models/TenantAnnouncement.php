<?php

namespace App\Models;

use App\Models\Concerns\BelongsToTenant;
use Illuminate\Database\Eloquent\Relations\BelongsTo;

class TenantAnnouncement extends BaseModel
{
    use BelongsToTenant;

    protected $table = 'tenant_announcements';

    protected $fillable = [
        'id',
        'tenant_id',
        'title',
        'slug',
        'summary',
        'body',
        'status',
        'modal_enabled',
        'important',
        'display_start_at',
        'display_end_at',
        'sort_order',
        'image_full_asset_id',
        'image_thumb_asset_id',
        'metadata_json',
        'created_at',
        'updated_at',
    ];

    protected $casts = [
        'modal_enabled' => 'boolean',
        'important' => 'boolean',
        'display_start_at' => 'datetime',
        'display_end_at' => 'datetime',
        'sort_order' => 'integer',
        'metadata_json' => 'array',
    ];

    public function tenant(): BelongsTo
    {
        return $this->belongsTo(PartnerTenant::class, 'tenant_id');
    }

    public function fullAsset(): BelongsTo
    {
        return $this->belongsTo(PlatformAsset::class, 'image_full_asset_id');
    }

    public function thumbAsset(): BelongsTo
    {
        return $this->belongsTo(PlatformAsset::class, 'image_thumb_asset_id');
    }
}
