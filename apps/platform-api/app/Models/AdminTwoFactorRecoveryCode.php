<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Relations\BelongsTo;

class AdminTwoFactorRecoveryCode extends BaseModel
{
    protected $table = 'admin_two_factor_recovery_codes';

    protected $fillable = [
        'id',
        'admin_user_id',
        'code_hash',
        'used_at',
        'created_at',
        'updated_at',
    ];

    protected $hidden = [
        'code_hash',
    ];

    protected $casts = [
        'used_at' => 'datetime',
    ];

    public function adminUser(): BelongsTo
    {
        return $this->belongsTo(AdminUser::class, 'admin_user_id');
    }
}
