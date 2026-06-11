<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Relations\BelongsTo;

class RewardEntrySubmission extends BaseModel
{
    protected $table = 'reward_entry_submissions';

    protected $fillable = [
        'id',
        'session_id',
        'game_id',
        'admin_user_id',
        'status',
        'prizes_json',
        'diff_to_scraper_json',
        'submitted_at',
        'created_at',
        'updated_at',
    ];

    protected $casts = [
        'prizes_json' => 'array',
        'diff_to_scraper_json' => 'array',
        'submitted_at' => 'datetime',
    ];

    public function session(): BelongsTo
    {
        return $this->belongsTo(RewardEntrySession::class, 'session_id');
    }

    public function adminUser(): BelongsTo
    {
        return $this->belongsTo(AdminUser::class, 'admin_user_id');
    }
}
