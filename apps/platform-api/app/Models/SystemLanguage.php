<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Relations\HasMany;

class SystemLanguage extends BaseModel
{
    protected $table = 'system_languages';

    protected $fillable = [
        'id',
        'locale',
        'name',
        'native_name',
        'status',
        'is_default',
        'sort_order',
        'created_at',
        'updated_at',
    ];

    protected $casts = [
        'is_default' => 'boolean',
        'sort_order' => 'integer',
    ];

    public function values(): HasMany
    {
        return $this->hasMany(SystemTranslationValue::class, 'language_id');
    }
}
