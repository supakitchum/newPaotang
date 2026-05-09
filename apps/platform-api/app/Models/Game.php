<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Relations\HasMany;
use Illuminate\Database\Eloquent\Relations\HasOne;

class Game extends BaseModel
{
    protected $table = 'games';

    protected $fillable = [
        'id',
        'code',
        'name',
        'draw_at',
        'close_at',
        'closed_at',
        'archived_at',
        'status',
        'metadata_json',
        'created_at',
        'updated_at',
    ];

    protected $casts = [
        'draw_at' => 'datetime',
        'close_at' => 'datetime',
        'closed_at' => 'datetime',
        'archived_at' => 'datetime',
        'metadata_json' => 'array',
    ];

    public function stockItems(): HasMany
    {
        return $this->hasMany(StockItem::class, 'game_id');
    }

    public function localStockItems(): HasMany
    {
        return $this->hasMany(LocalStockItem::class, 'game_id');
    }

    public function stockGenerationBatches(): HasMany
    {
        return $this->hasMany(StockGenerationBatch::class, 'game_id');
    }

    public function rewardResult(): HasOne
    {
        return $this->hasOne(RewardResult::class, 'game_id');
    }

    public function tickets(): HasMany
    {
        return $this->hasMany(Ticket::class, 'game_id');
    }
}
