<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::create('stock_allocation_jobs', function (Blueprint $table): void {
            $table->string('id', 40)->primary();
            $table->string('type', 60);
            $table->string('status', 40)->default('queued');
            $table->string('game_id', 40)->nullable();
            $table->string('allocation_id', 40)->nullable();
            $table->string('created_by_admin_id', 40);
            $table->string('idempotency_key', 128)->nullable();
            $table->string('payload_hash', 64)->nullable();
            $table->json('payload_json')->nullable();
            $table->json('actor_snapshot_json')->nullable();
            $table->unsignedInteger('progress_current')->default(0);
            $table->unsignedInteger('progress_total')->default(1);
            $table->unsignedTinyInteger('progress_percent')->default(0);
            $table->unsignedInteger('created_count')->default(0);
            $table->unsignedInteger('skipped_count')->default(0);
            $table->unsignedInteger('failed_count')->default(0);
            $table->string('current_step')->nullable();
            $table->string('error_code')->nullable();
            $table->text('error_message')->nullable();
            $table->json('result_json')->nullable();
            $table->timestampTz('queued_at')->nullable();
            $table->timestampTz('started_at')->nullable();
            $table->timestampTz('heartbeat_at')->nullable();
            $table->timestampTz('completed_at')->nullable();
            $table->timestampTz('failed_at')->nullable();
            $table->timestampTz('cancelled_at')->nullable();
            $table->timestampsTz();

            $table->index(['status', 'created_at']);
            $table->index(['game_id', 'status']);
            $table->index(['created_by_admin_id', 'created_at']);
            $table->unique(['created_by_admin_id', 'idempotency_key'], 'saj_admin_idempotency_unique');
        });

        Schema::create('stock_allocation_job_items', function (Blueprint $table): void {
            $table->string('id', 40)->primary();
            $table->string('job_id', 40);
            $table->string('partner_id', 40)->nullable();
            $table->string('tenant_id', 40)->nullable();
            $table->string('allocation_id', 40)->nullable();
            $table->string('status', 40)->default('queued');
            $table->unsignedInteger('percent_basis_points')->default(0);
            $table->unsignedInteger('target_count')->default(0);
            $table->string('message')->nullable();
            $table->text('error_message')->nullable();
            $table->timestampsTz();

            $table->foreign('job_id')->references('id')->on('stock_allocation_jobs')->cascadeOnDelete();
            $table->index(['job_id', 'status']);
            $table->index(['partner_id', 'tenant_id']);
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('stock_allocation_job_items');
        Schema::dropIfExists('stock_allocation_jobs');
    }
};
