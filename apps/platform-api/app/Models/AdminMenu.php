<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Relations\BelongsTo;
use Illuminate\Database\Eloquent\Relations\BelongsToMany;
use Illuminate\Database\Eloquent\Relations\HasMany;

class AdminMenu extends BaseModel
{
    protected $table = 'admin_menus';

    protected $fillable = [
        'id',
        'scope_type',
        'parent_id',
        'code',
        'label',
        'route',
        'category',
        'icon',
        'required_permission_code',
        'sort_order',
        'status',
        'created_at',
        'updated_at',
    ];

    protected $casts = [
        'sort_order' => 'integer',
    ];

    public function parent(): BelongsTo
    {
        return $this->belongsTo(self::class, 'parent_id');
    }

    public function children(): HasMany
    {
        return $this->hasMany(self::class, 'parent_id');
    }

    public function roles(): BelongsToMany
    {
        return $this->belongsToMany(Role::class, 'role_menus', 'menu_id', 'role_id')
            ->withTimestamps();
    }
}
