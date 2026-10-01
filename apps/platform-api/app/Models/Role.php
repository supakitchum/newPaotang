<?php

namespace App\Models;

use App\Models\Concerns\BelongsToTenant;
use Illuminate\Database\Eloquent\Relations\BelongsToMany;

class Role extends BaseModel
{
    use BelongsToTenant;

    protected $table = 'roles';

    protected $fillable = [
        'id',
        'scope_type',
        'tenant_id',
        'code',
        'name',
        'status',
        'version',
        'created_at',
        'updated_at',
    ];

    protected $casts = [
        'version' => 'integer',
    ];

    public function permissions(): BelongsToMany
    {
        return $this->belongsToMany(Permission::class, 'role_permissions', 'role_id', 'permission_id')
            ->withTimestamps();
    }

    public function menus(): BelongsToMany
    {
        return $this->belongsToMany(AdminMenu::class, 'role_menus', 'role_id', 'menu_id')
            ->withTimestamps();
    }

    public function adminUsers(): BelongsToMany
    {
        return $this->belongsToMany(AdminUser::class, 'admin_user_roles', 'role_id', 'admin_user_id')
            ->withPivot('scope_id')
            ->withTimestamps();
    }
}
