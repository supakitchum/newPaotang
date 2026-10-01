<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Relations\BelongsTo;
use Illuminate\Database\Eloquent\Relations\HasMany;

class SystemTranslationDeployRequest extends BaseModel
{
    protected $table = 'system_translation_deploy_requests';

    protected $fillable = [
        'id',
        'language_id',
        'locale',
        'surface',
        'category',
        'status',
        'title',
        'summary_json',
        'submitted_by_admin_id',
        'submitted_at',
        'reviewed_by_admin_id',
        'reviewed_at',
        'review_note',
        'deployed_at',
        'created_at',
        'updated_at',
    ];

    protected $casts = [
        'summary_json' => 'array',
        'submitted_at' => 'datetime',
        'reviewed_at' => 'datetime',
        'deployed_at' => 'datetime',
    ];

    public function language(): BelongsTo
    {
        return $this->belongsTo(SystemLanguage::class, 'language_id');
    }

    public function items(): HasMany
    {
        return $this->hasMany(SystemTranslationDeployRequestItem::class, 'deploy_request_id');
    }
}
