<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Relations\BelongsTo;

class SystemTranslationDeployRequestItem extends BaseModel
{
    protected $table = 'system_translation_deploy_request_items';

    protected $fillable = [
        'id',
        'deploy_request_id',
        'translation_key_id',
        'current_value',
        'draft_value',
        'variables_json',
        'validation_errors_json',
        'created_at',
        'updated_at',
    ];

    protected $casts = [
        'variables_json' => 'array',
        'validation_errors_json' => 'array',
    ];

    public function request(): BelongsTo
    {
        return $this->belongsTo(SystemTranslationDeployRequest::class, 'deploy_request_id');
    }

    public function key(): BelongsTo
    {
        return $this->belongsTo(SystemTranslationKey::class, 'translation_key_id');
    }
}
