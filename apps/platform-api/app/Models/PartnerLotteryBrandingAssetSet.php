<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Relations\BelongsTo;

class PartnerLotteryBrandingAssetSet extends BaseModel
{
    protected $table = 'partner_lottery_branding_asset_sets';

    protected $fillable = [
        'id',
        'partner_id',
        'version',
        'status',
        'logo_qr_asset_id',
        'right_sidebar_asset_id',
        'logo_bottom_asset_id',
        'logo_qr_storage_path',
        'right_sidebar_storage_path',
        'logo_bottom_storage_path',
        'uploaded_by_admin_id',
        'activated_at',
        'locked_at',
        'created_at',
        'updated_at',
    ];

    protected $casts = [
        'activated_at' => 'datetime',
        'locked_at' => 'datetime',
    ];

    public function partner(): BelongsTo
    {
        return $this->belongsTo(Partner::class, 'partner_id');
    }

    public function logoQrAsset(): BelongsTo
    {
        return $this->belongsTo(PlatformAsset::class, 'logo_qr_asset_id');
    }

    public function rightSidebarAsset(): BelongsTo
    {
        return $this->belongsTo(PlatformAsset::class, 'right_sidebar_asset_id');
    }

    public function logoBottomAsset(): BelongsTo
    {
        return $this->belongsTo(PlatformAsset::class, 'logo_bottom_asset_id');
    }
}
