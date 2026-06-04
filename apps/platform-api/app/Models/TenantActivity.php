<?php

namespace App\Models;

use App\Models\Concerns\BelongsToTenant;
use Illuminate\Database\Eloquent\Relations\BelongsTo;
use Illuminate\Database\Eloquent\Relations\HasMany;
use Illuminate\Database\Eloquent\Relations\HasOne;

class TenantActivity extends BaseModel
{
    use BelongsToTenant;

    protected $table = 'tenant_activities';

    protected $fillable = [
        'id',
        'tenant_id',
        'game_id',
        'name',
        'slug',
        'type',
        'status',
        'sort_order',
        'image_full_asset_id',
        'image_thumb_asset_id',
        'metadata_json',
        'created_at',
        'updated_at',
    ];

    protected $casts = [
        'sort_order' => 'integer',
        'metadata_json' => 'array',
    ];

    public function game(): BelongsTo
    {
        return $this->belongsTo(Game::class, 'game_id');
    }

    public function fullAsset(): BelongsTo
    {
        return $this->belongsTo(PlatformAsset::class, 'image_full_asset_id');
    }

    public function thumbAsset(): BelongsTo
    {
        return $this->belongsTo(PlatformAsset::class, 'image_thumb_asset_id');
    }

    public function luckyConfig(): HasOne
    {
        return $this->hasOne(TenantActivityLuckyConfig::class, 'activity_id');
    }

    public function cashbackConfig(): HasOne
    {
        return $this->hasOne(TenantActivityCashbackConfig::class, 'activity_id');
    }

    public function entries(): HasMany
    {
        return $this->hasMany(TenantActivityEntry::class, 'activity_id');
    }

    public function awards(): HasMany
    {
        return $this->hasMany(TenantActivityAward::class, 'activity_id');
    }
}
