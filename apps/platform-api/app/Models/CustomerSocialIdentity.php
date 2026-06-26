<?php

namespace App\Models;

use App\Models\Concerns\BelongsToTenant;
use Illuminate\Database\Eloquent\Relations\BelongsTo;

class CustomerSocialIdentity extends BaseModel
{
    use BelongsToTenant;

    protected $table = 'customer_social_identities';

    protected $fillable = [
        'id',
        'tenant_id',
        'customer_id',
        'provider',
        'provider_user_id',
        'email',
        'display_name',
        'avatar_url',
        'linked_at',
        'last_login_at',
        'metadata_json',
        'created_at',
        'updated_at',
    ];

    protected $casts = [
        'linked_at' => 'datetime',
        'last_login_at' => 'datetime',
        'metadata_json' => 'array',
    ];

    public function customer(): BelongsTo
    {
        return $this->belongsTo(Customer::class, 'customer_id');
    }
}
