<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::create('customers', function (Blueprint $table): void {
            $table->string('id', 30)->primary();
            $table->string('tenant_id', 30);
            $table->string('phone')->nullable();
            $table->string('name')->nullable();
            $table->string('status')->default('active');
            $table->timestampsTz();

            $table->foreign('tenant_id')->references('id')->on('partner_tenants')->cascadeOnDelete();
            $table->unique(['tenant_id', 'phone']);
            $table->index(['tenant_id', 'status']);
        });

        Schema::create('customer_auth_sessions', function (Blueprint $table): void {
            $table->string('id', 34)->primary();
            $table->string('tenant_id', 30);
            $table->string('customer_id', 30);
            $table->string('access_token_hash', 64)->unique();
            $table->timestampTz('access_expires_at');
            $table->timestampTz('revoked_at')->nullable();
            $table->timestampTz('last_used_at')->nullable();
            $table->timestampsTz();

            $table->foreign('tenant_id')->references('id')->on('partner_tenants')->cascadeOnDelete();
            $table->foreign('customer_id')->references('id')->on('customers')->cascadeOnDelete();
            $table->index(['tenant_id', 'customer_id', 'revoked_at']);
            $table->index('access_expires_at');
        });

        Schema::create('local_stock_items', function (Blueprint $table): void {
            $table->string('id', 30)->primary();
            $table->string('tenant_id', 30);
            $table->string('partner_id', 30);
            $table->string('store_id', 128)->nullable();
            $table->string('game_id', 30);
            $table->string('stock_item_id', 30);
            $table->string('allocation_id', 34)->nullable();
            $table->string('full_number', 32);
            $table->string('front3', 3)->nullable();
            $table->string('back3', 3)->nullable();
            $table->string('back2', 2)->nullable();
            $table->string('image_url')->nullable();
            $table->string('image_thumb_url')->nullable();
            $table->string('status')->default('available');
            $table->timestampTz('synced_at')->nullable();
            $table->timestampTz('reserved_at')->nullable();
            $table->timestampTz('sold_at')->nullable();
            $table->timestampsTz();

            $table->foreign('tenant_id')->references('id')->on('partner_tenants')->cascadeOnDelete();
            $table->foreign('partner_id')->references('id')->on('partners')->cascadeOnDelete();
            $table->foreign('game_id')->references('id')->on('games')->cascadeOnDelete();
            $table->foreign('stock_item_id')->references('id')->on('stock_items')->cascadeOnDelete();
            $table->foreign('allocation_id')->references('id')->on('partner_stock_allocations')->nullOnDelete();
            $table->unique(['tenant_id', 'stock_item_id']);
            $table->index(['tenant_id', 'game_id', 'status']);
            $table->index(['tenant_id', 'game_id', 'store_id', 'status']);
            $table->index(['tenant_id', 'game_id', 'full_number']);
            $table->index(['tenant_id', 'game_id', 'front3', 'status']);
            $table->index(['tenant_id', 'game_id', 'back3', 'status']);
            $table->index(['tenant_id', 'game_id', 'back2', 'status']);
            $table->index(['allocation_id', 'status']);
        });

        Schema::create('stock_sync_batches', function (Blueprint $table): void {
            $table->string('id', 30)->primary();
            $table->string('tenant_id', 30);
            $table->string('partner_id', 30);
            $table->string('allocation_id', 34)->nullable();
            $table->string('status')->default('pending');
            $table->string('cursor', 64)->nullable();
            $table->unsignedInteger('processed_count')->default(0);
            $table->string('idempotency_key', 128)->nullable();
            $table->string('payload_hash', 64)->nullable();
            $table->string('requested_by_admin_id', 30)->nullable();
            $table->json('payload_json')->nullable();
            $table->timestampTz('started_at')->nullable();
            $table->timestampTz('completed_at')->nullable();
            $table->timestampsTz();

            $table->foreign('tenant_id')->references('id')->on('partner_tenants')->cascadeOnDelete();
            $table->foreign('partner_id')->references('id')->on('partners')->cascadeOnDelete();
            $table->foreign('allocation_id')->references('id')->on('partner_stock_allocations')->nullOnDelete();
            $table->foreign('requested_by_admin_id')->references('id')->on('admin_users')->nullOnDelete();
            $table->index(['tenant_id', 'status', 'created_at']);
            $table->index(['tenant_id', 'cursor']);
            $table->index(['requested_by_admin_id', 'idempotency_key']);
        });

        Schema::create('sync_inbox', function (Blueprint $table): void {
            $table->string('id', 34)->primary();
            $table->string('event_id', 34)->unique();
            $table->string('event_type');
            $table->unsignedInteger('event_version')->default(1);
            $table->string('consumer');
            $table->string('tenant_id', 30)->nullable();
            $table->string('partner_id', 30)->nullable();
            $table->string('game_id', 30)->nullable();
            $table->string('idempotency_key', 128)->nullable();
            $table->string('payload_hash', 64)->nullable();
            $table->string('status')->default('pending');
            $table->timestampTz('processed_at')->nullable();
            $table->text('last_error')->nullable();
            $table->timestampsTz();

            $table->foreign('tenant_id')->references('id')->on('partner_tenants')->nullOnDelete();
            $table->foreign('partner_id')->references('id')->on('partners')->nullOnDelete();
            $table->foreign('game_id')->references('id')->on('games')->nullOnDelete();
            $table->index(['tenant_id', 'status']);
            $table->index(['event_type', 'created_at']);
        });

        Schema::create('stock_reservations', function (Blueprint $table): void {
            $table->string('id', 30)->primary();
            $table->string('tenant_id', 30);
            $table->string('customer_id', 30);
            $table->string('game_id', 30);
            $table->string('status')->default('active');
            $table->timestampTz('expires_at');
            $table->timestampTz('released_at')->nullable();
            $table->timestampTz('cancelled_at')->nullable();
            $table->timestampTz('converted_at')->nullable();
            $table->string('idempotency_key', 128)->nullable();
            $table->string('payload_hash', 64)->nullable();
            $table->string('released_idempotency_key', 128)->nullable();
            $table->string('released_payload_hash', 64)->nullable();
            $table->string('cancelled_idempotency_key', 128)->nullable();
            $table->string('cancelled_payload_hash', 64)->nullable();
            $table->string('cancelled_by_admin_id', 30)->nullable();
            $table->text('cancel_reason')->nullable();
            $table->timestampsTz();

            $table->foreign('tenant_id')->references('id')->on('partner_tenants')->cascadeOnDelete();
            $table->foreign('customer_id')->references('id')->on('customers')->cascadeOnDelete();
            $table->foreign('game_id')->references('id')->on('games')->cascadeOnDelete();
            $table->foreign('cancelled_by_admin_id')->references('id')->on('admin_users')->nullOnDelete();
            $table->index(['tenant_id', 'status', 'expires_at']);
            $table->index(['tenant_id', 'customer_id', 'status']);
            $table->index(['tenant_id', 'customer_id', 'idempotency_key']);
        });

        Schema::create('stock_reservation_items', function (Blueprint $table): void {
            $table->string('reservation_id', 30);
            $table->string('local_stock_item_id', 30);
            $table->string('tenant_id', 30);
            $table->string('game_id', 30);
            $table->string('status')->default('active');
            $table->timestampsTz();

            $table->primary(['reservation_id', 'local_stock_item_id']);
            $table->foreign('reservation_id')->references('id')->on('stock_reservations')->cascadeOnDelete();
            $table->foreign('local_stock_item_id')->references('id')->on('local_stock_items')->cascadeOnDelete();
            $table->foreign('tenant_id')->references('id')->on('partner_tenants')->cascadeOnDelete();
            $table->foreign('game_id')->references('id')->on('games')->cascadeOnDelete();
            $table->index(['tenant_id', 'local_stock_item_id']);
            $table->index(['tenant_id', 'game_id']);
        });

        Schema::create('tenant_stock_export_jobs', function (Blueprint $table): void {
            $table->string('id', 30)->primary();
            $table->string('tenant_id', 30);
            $table->string('status')->default('pending');
            $table->string('idempotency_key', 128)->nullable();
            $table->string('payload_hash', 64)->nullable();
            $table->string('requested_by_admin_id', 30)->nullable();
            $table->json('payload_json')->nullable();
            $table->timestampsTz();

            $table->foreign('tenant_id')->references('id')->on('partner_tenants')->cascadeOnDelete();
            $table->foreign('requested_by_admin_id')->references('id')->on('admin_users')->nullOnDelete();
            $table->index(['tenant_id', 'status', 'created_at']);
            $table->index(['requested_by_admin_id', 'idempotency_key']);
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('tenant_stock_export_jobs');
        Schema::dropIfExists('stock_reservation_items');
        Schema::dropIfExists('stock_reservations');
        Schema::dropIfExists('sync_inbox');
        Schema::dropIfExists('stock_sync_batches');
        Schema::dropIfExists('local_stock_items');
        Schema::dropIfExists('customer_auth_sessions');
        Schema::dropIfExists('customers');
    }
};
