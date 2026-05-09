<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Relations\BelongsTo;

class AdminPermissionCacheVersion extends BaseModel
{
    protected $table = 'admin_permission_cache_versions';

    protected $fillable = [
        'id',
        'admin_user_id',
        'scope_id',
        'version',
        'created_at',
        'updated_at',
    ];

    protected $casts = [
        'version' => 'integer',
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
