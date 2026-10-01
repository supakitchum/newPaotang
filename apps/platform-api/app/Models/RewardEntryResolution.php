<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Relations\BelongsTo;

class RewardEntryResolution extends BaseModel
{
    protected $table = 'reward_entry_resolutions';

    protected $fillable = [
        'id',
        'session_id',
        'game_id',
        'reward_result_id',
        'selected_source_type',
        'selected_submission_id',
        'final_prizes_json',
        'reason',
        'resolved_by_admin_id',
        'resolved_at',
        'created_at',
        'updated_at',
    ];

    protected $casts = [
        'final_prizes_json' => 'array',
        'resolved_at' => 'datetime',
    ];

    public function session(): BelongsTo
    {
        return $this->belongsTo(RewardEntrySession::class, 'session_id');
    }

    public function submission(): BelongsTo
    {
        return $this->belongsTo(RewardEntrySubmission::class, 'selected_submission_id');
    }
}
