<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::create('lottery_image_background_zip_imports', function (Blueprint $table): void {
            $table->string('id', 40)->primary();
            $table->string('game_id', 40);
            $table->string('version', 40);
            $table->string('set_type', 40);
            $table->string('desired_status', 40)->default('ready');
            $table->boolean('supersede_existing')->default(false);
            $table->string('status', 40)->default('queued');
            $table->string('storage_driver', 40)->nullable();
            $table->string('zip_storage_key');
            $table->string('zip_file_name')->nullable();
            $table->unsignedBigInteger('zip_size_bytes')->default(0);
            $table->string('idempotency_key', 128)->nullable();
            $table->string('payload_hash', 64)->nullable();
            $table->string('created_by_admin_id', 40);
            $table->unsignedInteger('detected_count')->default(0);
            $table->unsignedInteger('processed_count')->default(0);
            $table->unsignedInteger('imported_count')->default(0);
            $table->unsignedTinyInteger('progress_percent')->default(0);
            $table->string('error_code')->nullable();
            $table->text('error_message')->nullable();
            $table->json('error_details_json')->nullable();
            $table->json('payload_json')->nullable();
            $table->json('actor_snapshot_json')->nullable();
            $table->json('result_json')->nullable();
            $table->timestampTz('queued_at')->nullable();
            $table->timestampTz('started_at')->nullable();
            $table->timestampTz('completed_at')->nullable();
            $table->timestampTz('failed_at')->nullable();
            $table->timestampsTz();

            $table->index(['game_id', 'version', 'set_type']);
            $table->index(['status', 'created_at']);
            $table->index(['created_by_admin_id', 'created_at']);
            $table->unique(['created_by_admin_id', 'idempotency_key'], 'lbzi_admin_idempotency_unique');
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('lottery_image_background_zip_imports');
    }
};
