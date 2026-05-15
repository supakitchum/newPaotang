<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::table('stock_generation_batches', function (Blueprint $table): void {
            $table->unsignedInteger('total_rounds')->default(0);
            $table->unsignedInteger('processed_rounds')->default(0);
            $table->unsignedInteger('chunk_rounds')->default(0);
            $table->timestampTz('started_at')->nullable();
            $table->timestampTz('failed_at')->nullable();
            $table->text('failure_reason')->nullable();
            $table->index(['type', 'status', 'created_at'], 'stock_generation_batches_type_status_created_index');
        });

        Schema::create('stock_generation_batch_chunks', function (Blueprint $table): void {
            $table->string('id', 34)->primary();
            $table->string('batch_id', 30);
            $table->unsignedInteger('chunk_index');
            $table->unsignedInteger('start_round');
            $table->unsignedInteger('round_count');
            $table->string('status')->default('queued');
            $table->unsignedInteger('attempt_count')->default(0);
            $table->timestampTz('started_at')->nullable();
            $table->timestampTz('completed_at')->nullable();
            $table->timestampTz('failed_at')->nullable();
            $table->text('failure_reason')->nullable();
            $table->timestampsTz();

            $table->foreign('batch_id')->references('id')->on('stock_generation_batches')->cascadeOnDelete();
            $table->unique(['batch_id', 'chunk_index'], 'stock_generation_batch_chunks_batch_index_unique');
            $table->index(['batch_id', 'status'], 'stock_generation_batch_chunks_batch_status_index');
            $table->index(['status', 'created_at'], 'stock_generation_batch_chunks_status_created_index');
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('stock_generation_batch_chunks');

        Schema::table('stock_generation_batches', function (Blueprint $table): void {
            $table->dropIndex('stock_generation_batches_type_status_created_index');
            $table->dropColumn([
                'total_rounds',
                'processed_rounds',
                'chunk_rounds',
                'started_at',
                'failed_at',
                'failure_reason',
            ]);
        });
    }
};
