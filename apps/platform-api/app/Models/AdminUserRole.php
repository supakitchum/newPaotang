<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Relations\BelongsTo;

class AdminUserRole extends BasePivotModel
{
    protected $table = 'admin_user_roles';

    protected $fillable = [
        'admin_user_id',
        'role_id',
        'scope_id',
        'created_at',
        'updated_at',
    ];

    public function adminUser(): BelongsTo
    {
        return $this->belongsTo(AdminUser::class, 'admin_user_id');
    }

    public function role(): BelongsTo
    {
        return $this->belongsTo(Role::class, 'role_id');
    }

    public function scope(): BelongsTo
    {
        return $this->belongsTo(AdminScope::class, 'scope_id');
    }
}
