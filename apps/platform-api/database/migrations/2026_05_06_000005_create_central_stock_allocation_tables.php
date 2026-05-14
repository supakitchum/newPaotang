<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::create('games', function (Blueprint $table): void {
            $table->string('id', 30)->primary();
            $table->string('code')->unique();
            $table->string('name');
            $table->timestampTz('draw_at');
            $table->timestampTz('close_at')->nullable();
            $table->timestampTz('closed_at')->nullable();
            $table->timestampTz('archived_at')->nullable();
            $table->string('status')->default('draft');
            $table->json('metadata_json')->nullable();
            $table->timestampsTz();
            $table->index(['status', 'draw_at']);
        });

        Schema::create('stock_generation_batches', function (Blueprint $table): void {
            $table->string('id', 30)->primary();
            $table->string('game_id', 30);
            $table->string('type')->default('generate');
            $table->string('status')->default('pending');
            $table->unsignedInteger('requested_count')->default(0);
            $table->unsignedInteger('generated_count')->default(0);
            $table->string('range_start')->nullable();
            $table->string('range_end')->nullable();
            $table->unsignedTinyInteger('number_digits')->default(6);
            $table->string('idempotency_key', 128)->nullable();
            $table->string('payload_hash', 64)->nullable();
            $table->string('created_by_admin_id', 30)->nullable();
            $table->json('payload_json')->nullable();
            $table->timestampTz('completed_at')->nullable();
            $table->timestampsTz();

            $table->foreign('game_id')->references('id')->on('games')->cascadeOnDelete();
            $table->foreign('created_by_admin_id')->references('id')->on('admin_users')->nullOnDelete();
            $table->index(['game_id', 'type', 'payload_hash']);
            $table->index(['game_id', 'status']);
        });

        Schema::create('partner_quotas', function (Blueprint $table): void {
            $table->string('id', 30)->primary();
            $table->string('partner_id', 30);
            $table->string('game_id', 30);
            $table->unsignedInteger('quota_count');
            $table->unsignedInteger('allocated_count')->default(0);
            $table->string('status')->default('active');
            $table->string('created_by_admin_id', 30)->nullable();
            $table->timestampsTz();

            $table->foreign('partner_id')->references('id')->on('partners')->cascadeOnDelete();
            $table->foreign('game_id')->references('id')->on('games')->cascadeOnDelete();
            $table->foreign('created_by_admin_id')->references('id')->on('admin_users')->nullOnDelete();
            $table->unique(['partner_id', 'game_id']);
            $table->index(['game_id', 'status']);
        });

        Schema::create('partner_stock_allocations', function (Blueprint $table): void {
            $table->string('id', 34)->primary();
            $table->string('partner_id', 30);
            $table->string('tenant_id', 30);
            $table->string('game_id', 30);
            $table->string('quota_id', 30)->nullable();
            $table->string('status')->default('pending');
            $table->unsignedInteger('requested_count');
            $table->unsignedInteger('allocated_count')->default(0);
            $table->string('idempotency_key', 128)->nullable();
            $table->string('created_by_admin_id', 30)->nullable();
            $table->text('reason')->nullable();
            $table->timestampTz('cancelled_at')->nullable();
            $table->timestampsTz();

            $table->foreign('partner_id')->references('id')->on('partners')->cascadeOnDelete();
            $table->foreign('tenant_id')->references('id')->on('partner_tenants')->cascadeOnDelete();
            $table->foreign('game_id')->references('id')->on('games')->cascadeOnDelete();
            $table->foreign('quota_id')->references('id')->on('partner_quotas')->nullOnDelete();
            $table->foreign('created_by_admin_id')->references('id')->on('admin_users')->nullOnDelete();
            $table->index(['partner_id', 'tenant_id', 'game_id']);
            $table->index(['status', 'created_at']);
            $table->index(['created_by_admin_id', 'idempotency_key']);
        });

        Schema::create('stock_items', function (Blueprint $table): void {
            $table->string('id', 30)->primary();
            $table->string('game_id', 30);
            $table->string('batch_id', 30)->nullable();
            $table->string('full_number', 32);
            $table->string('front3', 3)->nullable();
            $table->string('back3', 3)->nullable();
            $table->string('back2', 2)->nullable();
            $table->string('status')->default('available');
            $table->string('partner_id', 30)->nullable();
            $table->string('tenant_id', 30)->nullable();
            $table->string('allocation_id', 34)->nullable();
            $table->text('recall_reason')->nullable();
            $table->timestampTz('recalled_at')->nullable();
            $table->timestampsTz();

            $table->foreign('game_id')->references('id')->on('games')->cascadeOnDelete();
            $table->foreign('batch_id')->references('id')->on('stock_generation_batches')->nullOnDelete();
            $table->foreign('partner_id')->references('id')->on('partners')->nullOnDelete();
            $table->foreign('tenant_id')->references('id')->on('partner_tenants')->nullOnDelete();
            $table->foreign('allocation_id')->references('id')->on('partner_stock_allocations')->nullOnDelete();
            $table->index(['game_id', 'full_number']);
            $table->index(['game_id', 'status', 'id']);
            $table->index(['allocation_id', 'status']);
            $table->index(['tenant_id', 'status']);
        });

        Schema::create('partner_stock_allocation_items', function (Blueprint $table): void {
            $table->string('allocation_id', 34);
            $table->string('stock_item_id', 30);
            $table->string('partner_id', 30);
            $table->string('tenant_id', 30);
            $table->string('game_id', 30);
            $table->string('status')->default('allocated');
            $table->timestampsTz();

            $table->primary(['allocation_id', 'stock_item_id']);
            $table->foreign('allocation_id')->references('id')->on('partner_stock_allocations')->cascadeOnDelete();
            $table->foreign('stock_item_id')->references('id')->on('stock_items')->cascadeOnDelete();
            $table->foreign('partner_id')->references('id')->on('partners')->cascadeOnDelete();
            $table->foreign('tenant_id')->references('id')->on('partner_tenants')->cascadeOnDelete();
            $table->foreign('game_id')->references('id')->on('games')->cascadeOnDelete();
            $table->index(['stock_item_id', 'status']);
            $table->index(['tenant_id', 'game_id']);
        });

        Schema::create('sync_outbox', function (Blueprint $table): void {
            $table->string('id', 34)->primary();
            $table->string('event_id', 34)->unique();
            $table->string('event_type');
            $table->unsignedInteger('event_version')->default(1);
            $table->string('producer');
            $table->string('tenant_id', 30)->nullable();
            $table->string('partner_id', 30)->nullable();
            $table->string('game_id', 30)->nullable();
            $table->string('aggregate_type')->nullable();
            $table->string('aggregate_id', 34)->nullable();
            $table->string('idempotency_key', 128)->nullable();
            $table->string('correlation_id')->nullable();
            $table->json('payload_json');
            $table->string('status')->default('pending');
            $table->unsignedInteger('attempt_count')->default(0);
            $table->timestampTz('available_at');
            $table->timestampTz('processed_at')->nullable();
            $table->text('last_error')->nullable();
            $table->timestampsTz();

            $table->foreign('tenant_id')->references('id')->on('partner_tenants')->nullOnDelete();
            $table->foreign('partner_id')->references('id')->on('partners')->nullOnDelete();
            $table->foreign('game_id')->references('id')->on('games')->nullOnDelete();
            $table->index(['status', 'available_at']);
            $table->index(['event_type', 'created_at']);
            $table->index(['tenant_id', 'status']);
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('sync_outbox');
        Schema::dropIfExists('partner_stock_allocation_items');
        Schema::dropIfExists('stock_items');
        Schema::dropIfExists('partner_stock_allocations');
        Schema::dropIfExists('partner_quotas');
        Schema::dropIfExists('stock_generation_batches');
        Schema::dropIfExists('games');
    }
};
