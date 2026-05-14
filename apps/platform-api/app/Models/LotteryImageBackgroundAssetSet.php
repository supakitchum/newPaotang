<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Relations\BelongsTo;

class LotteryImageBackgroundAssetSet extends BaseModel
{
    protected $table = 'lottery_image_background_asset_sets';

    protected $fillable = [
        'id',
        'game_id',
        'version',
        'set_type',
        'status',
        'source_asset_id',
        'full_asset_id',
        'thumb_asset_id',
        'source_storage_path',
        'full_storage_path',
        'thumb_storage_path',
        'source_content_type',
        'full_content_type',
        'thumb_content_type',
        'source_width',
        'source_height',
        'full_width',
        'full_height',
        'thumb_width',
        'thumb_height',
        'source_size_bytes',
        'full_size_bytes',
        'thumb_size_bytes',
        'uploaded_by_admin_id',
        'activated_at',
        'retired_at',
        'metadata_json',
        'created_at',
        'updated_at',
    ];

    protected $casts = [
        'source_width' => 'integer',
        'source_height' => 'integer',
        'full_width' => 'integer',
        'full_height' => 'integer',
        'thumb_width' => 'integer',
        'thumb_height' => 'integer',
        'source_size_bytes' => 'integer',
        'full_size_bytes' => 'integer',
        'thumb_size_bytes' => 'integer',
        'activated_at' => 'datetime',
        'retired_at' => 'datetime',
        'metadata_json' => 'array',
    ];

    public function game(): BelongsTo
    {
        return $this->belongsTo(Game::class, 'game_id');
    }

    public function sourceAsset(): BelongsTo
    {
        return $this->belongsTo(PlatformAsset::class, 'source_asset_id');
    }

    public function fullAsset(): BelongsTo
    {
        return $this->belongsTo(PlatformAsset::class, 'full_asset_id');
    }

    public function thumbAsset(): BelongsTo
    {
        return $this->belongsTo(PlatformAsset::class, 'thumb_asset_id');
    }
}
