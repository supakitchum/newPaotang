<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Relations\BelongsTo;

class AdminTwoFactorChallenge extends BaseModel
{
    protected $table = 'admin_two_factor_challenges';

    protected $fillable = [
        'id',
        'admin_user_id',
        'challenge_token_hash',
        'scope_type',
        'scope_id',
        'tenant_id',
        'status',
        'expires_at',
        'consumed_at',
        'created_at',
        'updated_at',
    ];

    protected $hidden = [
        'challenge_token_hash',
    ];

    protected $casts = [
        'expires_at' => 'datetime',
        'consumed_at' => 'datetime',
    ];

    public function adminUser(): BelongsTo
    {
        return $this->belongsTo(AdminUser::class, 'admin_user_id');
    }

    public function scope(): BelongsTo
    {
        return $this->belongsTo(AdminScope::class, 'scope_id');
    }
}
