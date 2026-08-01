<?php

namespace App\Models;

use App\Models\Concerns\BelongsToTenant;
use Illuminate\Database\Eloquent\Relations\BelongsTo;
use Illuminate\Support\Str;
use Laravel\Passkeys\Passkey;

class CustomerPasskey extends Passkey
{
    use BelongsToTenant;

    protected $table = 'customer_passkeys';

    public $incrementing = false;

    protected $keyType = 'string';

    protected $fillable = [
        'id',
        'tenant_id',
        'user_id',
        'name',
        'credential_id',
        'credential',
        'status',
        'last_used_at',
        'revoked_at',
        'created_at',
        'updated_at',
    ];

    protected $hidden = [
        'credential_id',
        'credential',
    ];

    protected static function booted(): void
    {
        static::creating(function (CustomerPasskey $passkey): void {
            $passkey->id = $passkey->id ?: 'cpk_'.Str::ulid()->toBase32();
            $passkey->status = $passkey->status ?: 'active';

            if (! $passkey->tenant_id && $passkey->user_id) {
                $passkey->tenant_id = Customer::query()
                    ->whereKey($passkey->user_id)
                    ->value('tenant_id');
            }
        });
    }

    protected function casts(): array
    {
        return [
            'credential' => 'array',
            'last_used_at' => 'datetime',
            'revoked_at' => 'datetime',
        ];
    }

    public function user(): BelongsTo
    {
        return $this->belongsTo(Customer::class, 'user_id');
    }
}
