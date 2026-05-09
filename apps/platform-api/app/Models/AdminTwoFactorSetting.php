<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Relations\BelongsTo;
use Illuminate\Database\Eloquent\Relations\HasMany;

class AdminTwoFactorSetting extends BaseModel
{
    protected $table = 'admin_two_factor_settings';

    protected $fillable = [
        'id',
        'admin_user_id',
        'status',
        'secret_encrypted',
        'secret_version',
        'enabled_at',
        'disabled_at',
        'last_verified_at',
        'metadata_json',
        'created_at',
        'updated_at',
    ];

    protected $hidden = [
        'secret_encrypted',
    ];

    protected $casts = [
        'secret_version' => 'integer',
        'enabled_at' => 'datetime',
        'disabled_at' => 'datetime',
        'last_verified_at' => 'datetime',
        'metadata_json' => 'array',
    ];

    public function adminUser(): BelongsTo
    {
        return $this->belongsTo(AdminUser::class, 'admin_user_id');
    }

    public function recoveryCodes(): HasMany
    {
        return $this->hasMany(AdminTwoFactorRecoveryCode::class, 'admin_user_id', 'admin_user_id');
    }
}
