<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Relations\BelongsTo;

class SystemTranslationValue extends BaseModel
{
    protected $table = 'system_translation_values';

    protected $fillable = [
        'id',
        'language_id',
        'translation_key_id',
        'value',
        'published_by_admin_id',
        'published_at',
        'created_at',
        'updated_at',
    ];

    protected $casts = [
        'published_at' => 'datetime',
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
