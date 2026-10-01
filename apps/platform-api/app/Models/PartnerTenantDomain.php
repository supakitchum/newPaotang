<?php

namespace App\Models;

use App\Models\Concerns\BelongsToTenant;
use Illuminate\Database\Eloquent\Relations\BelongsTo;

class PartnerTenantDomain extends BaseModel
{
    use BelongsToTenant;

    protected $table = 'partner_tenant_domains';

    protected $fillable = [
        'id',
        'partner_id',
        'tenant_id',
        'host',
        'type',
        'status',
        'is_primary',
        'verified_at',
        'ssl_ready_at',
        'dns_verified_at',
        'cloudflare_proxy_verified_at',
        'https_enforced_at',
        'cloudflare_readiness_checked_at',
        'created_at',
        'updated_at',
    ];

    protected $casts = [
        'is_primary' => 'boolean',
        'verified_at' => 'datetime',
        'ssl_ready_at' => 'datetime',
        'dns_verified_at' => 'datetime',
        'cloudflare_proxy_verified_at' => 'datetime',
        'https_enforced_at' => 'datetime',
        'cloudflare_readiness_checked_at' => 'datetime',
    ];

    public function partner(): BelongsTo
    {
        return $this->belongsTo(Partner::class, 'partner_id');
    }
}
