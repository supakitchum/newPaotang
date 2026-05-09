<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Relations\BelongsTo;

class AdminPasswordResetToken extends BaseModel
{
    protected $table = 'admin_password_reset_tokens';

    protected $fillable = [
        'id',
        'admin_user_id',
        'email_hash',
        'token_hash',
        'status',
        'expires_at',
        'consumed_at',
        'requested_ip',
        'requested_user_agent',
        'created_at',
        'updated_at',
    ];

    protected $hidden = [
        'token_hash',
        'email_hash',
    ];

    protected $casts = [
        'expires_at' => 'datetime',
        'consumed_at' => 'datetime',
    ];

    public function adminUser(): BelongsTo
    {
        return $this->belongsTo(AdminUser::class, 'admin_user_id');
    }
}
