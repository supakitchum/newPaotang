<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Relations\HasMany;

class SystemTranslationKey extends BaseModel
{
    protected $table = 'system_translation_keys';

    protected $fillable = [
        'id',
        'translation_key',
        'surface',
        'category',
        'default_text',
        'description',
        'variables_json',
        'status',
        'created_at',
        'updated_at',
    ];

    protected $casts = [
        'variables_json' => 'array',
    ];

    public function values(): HasMany
    {
        return $this->hasMany(SystemTranslationValue::class, 'translation_key_id');
    }

    public function drafts(): HasMany
    {
        return $this->hasMany(SystemTranslationDraft::class, 'translation_key_id');
    }
}
