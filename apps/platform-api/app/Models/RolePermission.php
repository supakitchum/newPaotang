<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Relations\BelongsTo;

class RolePermission extends BasePivotModel
{
    protected $table = 'role_permissions';

    protected $fillable = [
        'role_id',
        'permission_id',
        'created_at',
        'updated_at',
    ];

    public function role(): BelongsTo
    {
        return $this->belongsTo(Role::class, 'role_id');
    }

    public function permission(): BelongsTo
    {
        return $this->belongsTo(Permission::class, 'permission_id');
    }
}
