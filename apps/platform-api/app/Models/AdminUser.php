<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Relations\BelongsToMany;
use Illuminate\Database\Eloquent\Relations\HasMany;

class AdminUser extends BaseModel
{
    protected $table = 'admin_users';

    protected $fillable = [
        'id',
        'email',
        'username',
        'password_hash',
        'status',
        'preferred_locale',
        'created_at',
        'updated_at',
        'name',
        'phone',
        'two_factor_enabled',
    ];

    protected $hidden = [
        'password_hash',
    ];

    protected $casts = [
        'two_factor_enabled' => 'boolean',
        'last_login_at' => 'datetime',
    ];

    public function roles(): BelongsToMany
    {
        return $this->belongsToMany(Role::class, 'admin_user_roles', 'admin_user_id', 'role_id')
            ->withPivot('scope_id')
            ->withTimestamps();
    }

    public function scopes(): BelongsToMany
    {
        return $this->belongsToMany(AdminScope::class, 'admin_user_roles', 'admin_user_id', 'scope_id')
            ->withPivot('role_id')
            ->withTimestamps();
    }

    public function authSessions(): HasMany
    {
        return $this->hasMany(AdminAuthSession::class, 'admin_user_id');
    }
}
