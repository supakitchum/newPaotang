<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Relations\BelongsTo;

class LotteryImageMixSetting extends BaseModel
{
    protected $table = 'lottery_image_mix_settings';

    protected $fillable = [
        'id',
        'game_id',
        'odd_percentage',
        'even_percentage',
        'charity_percentage',
        'updated_by_admin_id',
        'created_at',
        'updated_at',
    ];

    protected $casts = [
        'odd_percentage' => 'integer',
        'even_percentage' => 'integer',
        'charity_percentage' => 'integer',
    ];

    public function game(): BelongsTo
    {
        return $this->belongsTo(Game::class, 'game_id');
    }
}
