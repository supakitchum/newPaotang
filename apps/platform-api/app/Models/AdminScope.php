<?php

namespace App\Models;

use App\Models\Concerns\BelongsToTenant;
use Illuminate\Database\Eloquent\Relations\BelongsTo;
use Illuminate\Database\Eloquent\Relations\BelongsToMany;

class AdminScope extends BaseModel
{
    use BelongsToTenant;

    protected $table = 'admin_scopes';

    protected $fillable = [
        'id',
        'scope_type',
        'tenant_id',
        'partner_id',
        'created_at',
        'updated_at',
    ];

    public function partner(): BelongsTo
    {
        return $this->belongsTo(Partner::class, 'partner_id');
    }

    public function adminUsers(): BelongsToMany
    {
        return $this->belongsToMany(AdminUser::class, 'admin_user_roles', 'scope_id', 'admin_user_id')
            ->withPivot('role_id')
            ->withTimestamps();
    }
}
