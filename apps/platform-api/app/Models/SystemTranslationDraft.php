<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Relations\BelongsTo;

class SystemTranslationDraft extends BaseModel
{
    protected $table = 'system_translation_drafts';

    protected $fillable = [
        'id',
        'language_id',
        'translation_key_id',
        'value',
        'status',
        'updated_by_admin_id',
        'created_at',
        'updated_at',
    ];

    public function language(): BelongsTo
    {
        return $this->belongsTo(SystemLanguage::class, 'language_id');
    }

    public function key(): BelongsTo
    {
        return $this->belongsTo(SystemTranslationKey::class, 'translation_key_id');
    }
}
