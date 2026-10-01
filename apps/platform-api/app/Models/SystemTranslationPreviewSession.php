<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Relations\BelongsTo;

class SystemTranslationPreviewSession extends BaseModel
{
    protected $table = 'system_translation_preview_sessions';

    protected $fillable = [
        'id',
        'deploy_request_id',
        'token_hash',
        'created_by_admin_id',
        'expires_at',
        'used_at',
        'created_at',
        'updated_at',
    ];

    protected $casts = [
        'expires_at' => 'datetime',
        'used_at' => 'datetime',
    ];

    public function request(): BelongsTo
    {
        return $this->belongsTo(SystemTranslationDeployRequest::class, 'deploy_request_id');
    }
}
