<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Relations\BelongsTo;

class RoleMenu extends BasePivotModel
{
    protected $table = 'role_menus';

    protected $fillable = [
        'role_id',
        'menu_id',
        'created_at',
        'updated_at',
    ];

    public function role(): BelongsTo
    {
        return $this->belongsTo(Role::class, 'role_id');
    }

    public function menu(): BelongsTo
    {
        return $this->belongsTo(AdminMenu::class, 'menu_id');
    }
}
