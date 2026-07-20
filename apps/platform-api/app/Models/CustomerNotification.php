<?php

namespace App\Models;

use App\Models\Concerns\BelongsToTenant;
use Illuminate\Database\Eloquent\Relations\HasMany;

class CustomerNotification extends BaseModel
{
    use BelongsToTenant;

    protected $fillable = [
        'id',
        'tenant_id',
        'event_key',
        'category',
        'title_json',
        'body_json',
        'icon_key',
        'action_key',
        'action_entity_id',
        'subject_type',
        'subject_id',
        'creator_type',
        'creator_id',
        'dedupe_key',
        'metadata_json',
        'published_at',
        'created_at',
        'updated_at',
    ];

    protected $casts = [
        'title_json' => 'array',
        'body_json' => 'array',
        'metadata_json' => 'array',
        'published_at' => 'datetime',
    ];

    public function recipients(): HasMany
    {
        return $this->hasMany(CustomerNotificationRecipient::class, 'notification_id');
    }
}
