<?php

namespace App\Models;

use App\Models\Concerns\BelongsToTenant;
use Illuminate\Database\Eloquent\Relations\BelongsTo;

class AdminAuthSession extends BaseModel
{
    use BelongsToTenant;

    protected $table = 'admin_auth_sessions';

    protected $fillable = [
        'id',
        'admin_user_id',
        'access_token_hash',
        'refresh_token_hash',
        'scope_type',
        'scope_id',
        'tenant_id',
        'access_expires_at',
        'refresh_expires_at',
        'revoked_at',
        'refreshed_from_id',
        'last_used_at',
        'created_at',
        'updated_at',
    ];

    protected $hidden = [
        'access_token_hash',
        'refresh_token_hash',
    ];

    protected $casts = [
        'access_expires_at' => 'datetime',
        'refresh_expires_at' => 'datetime',
        'revoked_at' => 'datetime',
        'last_used_at' => 'datetime',
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
