<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Relations\BelongsTo;

class AdminUserInvitation extends BaseModel
{
    protected $table = 'admin_user_invitations';

    protected $fillable = [
        'id',
        'admin_user_id',
        'scope_type',
        'tenant_id',
        'token_hash',
        'status',
        'expires_at',
        'accepted_at',
        'created_by_admin_id',
        'created_at',
        'updated_at',
    ];

    protected $hidden = [
        'token_hash',
    ];

    protected $casts = [
        'expires_at' => 'datetime',
        'accepted_at' => 'datetime',
    ];

    public function adminUser(): BelongsTo
    {
        return $this->belongsTo(AdminUser::class, 'admin_user_id');
    }
}
