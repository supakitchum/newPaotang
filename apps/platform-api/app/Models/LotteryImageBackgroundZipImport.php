<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Relations\BelongsTo;

class LotteryImageBackgroundZipImport extends BaseModel
{
    protected $table = 'lottery_image_background_zip_imports';

    protected $fillable = [
        'id',
        'game_id',
        'version',
        'set_type',
        'desired_status',
        'supersede_existing',
        'status',
        'storage_driver',
        'zip_storage_key',
        'zip_file_name',
        'zip_size_bytes',
        'idempotency_key',
        'payload_hash',
        'created_by_admin_id',
        'detected_count',
        'processed_count',
        'imported_count',
        'progress_percent',
        'current_step',
        'attempts',
        'max_attempts',
        'stale_after_seconds',
        'heartbeat_at',
        'last_error_at',
        'error_code',
        'error_message',
        'error_details_json',
        'payload_json',
        'actor_snapshot_json',
        'result_json',
        'queued_at',
        'started_at',
        'completed_at',
        'failed_at',
        'created_at',
        'updated_at',
    ];

    protected $casts = [
        'supersede_existing' => 'boolean',
        'zip_size_bytes' => 'integer',
        'detected_count' => 'integer',
        'processed_count' => 'integer',
        'imported_count' => 'integer',
        'progress_percent' => 'integer',
        'attempts' => 'integer',
        'max_attempts' => 'integer',
        'stale_after_seconds' => 'integer',
        'heartbeat_at' => 'datetime',
        'last_error_at' => 'datetime',
        'error_details_json' => 'array',
        'payload_json' => 'array',
        'actor_snapshot_json' => 'array',
        'result_json' => 'array',
        'queued_at' => 'datetime',
        'started_at' => 'datetime',
        'completed_at' => 'datetime',
        'failed_at' => 'datetime',
    ];

    public function createdByAdmin(): BelongsTo
    {
        return $this->belongsTo(AdminUser::class, 'created_by_admin_id');
    }
}
