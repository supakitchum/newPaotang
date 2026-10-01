<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::table('customers', function (Blueprint $table): void {
            $table->string('email')->nullable()->after('phone');
            $table->string('password_hash')->nullable()->after('email');
            $table->string('avatar_url')->nullable()->after('password_hash');
            $table->timestampTz('last_login_at')->nullable()->after('status');
            $table->index(['tenant_id', 'email']);
        });

        Schema::table('customer_auth_sessions', function (Blueprint $table): void {
            $table->string('refresh_token_hash', 64)->nullable()->unique()->after('access_token_hash');
            $table->timestampTz('refresh_expires_at')->nullable()->after('access_expires_at');
            $table->string('refreshed_from_id', 34)->nullable()->after('revoked_at');
            $table->index('refresh_expires_at');
            $table->index('refreshed_from_id');
        });

        Schema::create('idempotency_keys', function (Blueprint $table): void {
            $table->string('id', 34)->primary();
            $table->string('tenant_id', 30)->nullable();
            $table->string('actor_type');
            $table->string('actor_id', 128);
            $table->string('route_key');
            $table->string('permission_code')->nullable();
            $table->string('idempotency_key', 128);
            $table->string('payload_hash', 64);
            $table->unsignedSmallInteger('response_status')->nullable();
            $table->json('response_body_json')->nullable();
            $table->timestampTz('completed_at')->nullable();
            $table->timestampTz('expires_at');
            $table->timestampsTz();

            $table->foreign('tenant_id')->references('id')->on('partner_tenants')->nullOnDelete();
            $table->unique(['tenant_id', 'actor_type', 'actor_id', 'route_key', 'idempotency_key'], 'idem_actor_route_key_unique');
            $table->index(['expires_at']);
        });

        Schema::create('wallets', function (Blueprint $table): void {
            $table->string('id', 30)->primary();
            $table->string('tenant_id', 30);
            $table->string('customer_id', 30);
            $table->string('name')->default('Primary wallet');
            $table->string('type')->default('primary');
            $table->string('status')->default('active');
            $table->bigInteger('balance_amount')->default(0);
            $table->string('currency', 3)->default('THB');
            $table->timestampsTz();

            $table->foreign('tenant_id')->references('id')->on('partner_tenants')->cascadeOnDelete();
            $table->foreign('customer_id')->references('id')->on('customers')->cascadeOnDelete();
            $table->unique(['tenant_id', 'customer_id', 'type']);
            $table->index(['tenant_id', 'status']);
        });

        Schema::create('orders', function (Blueprint $table): void {
            $table->string('id', 30)->primary();
            $table->string('tenant_id', 30);
            $table->string('customer_id', 30);
            $table->string('reservation_id', 30);
            $table->string('game_id', 30);
            $table->string('wallet_id', 30)->nullable();
            $table->string('payment_method')->default('wallet');
            $table->string('status')->default('draft');
            $table->string('payment_status')->default('unpaid');
            $table->bigInteger('total_amount');
            $table->string('currency', 3)->default('THB');
            $table->string('reference')->nullable();
            $table->text('admin_note')->nullable();
            $table->string('idempotency_key', 128)->nullable();
            $table->string('payload_hash', 64)->nullable();
            $table->timestampTz('paid_at')->nullable();
            $table->timestampTz('cancelled_at')->nullable();
            $table->timestampTz('refunded_at')->nullable();
            $table->timestampsTz();

            $table->foreign('tenant_id')->references('id')->on('partner_tenants')->cascadeOnDelete();
            $table->foreign('customer_id')->references('id')->on('customers')->cascadeOnDelete();
            $table->foreign('reservation_id')->references('id')->on('stock_reservations')->cascadeOnDelete();
            $table->foreign('game_id')->references('id')->on('games')->cascadeOnDelete();
            $table->foreign('wallet_id')->references('id')->on('wallets')->nullOnDelete();
            $table->unique(['tenant_id', 'customer_id', 'idempotency_key']);
            $table->index(['tenant_id', 'customer_id', 'status', 'created_at']);
            $table->index(['tenant_id', 'status', 'created_at']);
        });

        Schema::create('tickets', function (Blueprint $table): void {
            $table->string('id', 30)->primary();
            $table->string('tenant_id', 30);
            $table->string('customer_id', 30);
            $table->string('order_id', 30);
            $table->string('local_stock_item_id', 30);
            $table->string('game_id', 30);
            $table->string('full_number', 32);
            $table->string('status')->default('active');
            $table->string('image_url')->nullable();
            $table->string('image_thumb_url')->nullable();
            $table->timestampsTz();

            $table->foreign('tenant_id')->references('id')->on('partner_tenants')->cascadeOnDelete();
            $table->foreign('customer_id')->references('id')->on('customers')->cascadeOnDelete();
            $table->foreign('order_id')->references('id')->on('orders')->cascadeOnDelete();
            $table->foreign('local_stock_item_id')->references('id')->on('local_stock_items')->cascadeOnDelete();
            $table->foreign('game_id')->references('id')->on('games')->cascadeOnDelete();
            $table->unique(['tenant_id', 'local_stock_item_id']);
            $table->index(['tenant_id', 'customer_id', 'game_id', 'status']);
            $table->index(['tenant_id', 'order_id']);
        });

        Schema::create('order_items', function (Blueprint $table): void {
            $table->string('id', 30)->primary();
            $table->string('tenant_id', 30);
            $table->string('order_id', 30);
            $table->string('local_stock_item_id', 30);
            $table->string('ticket_id', 30)->nullable();
            $table->string('status')->default('reserved');
            $table->bigInteger('price_amount');
            $table->string('currency', 3)->default('THB');
            $table->timestampsTz();

            $table->foreign('tenant_id')->references('id')->on('partner_tenants')->cascadeOnDelete();
            $table->foreign('order_id')->references('id')->on('orders')->cascadeOnDelete();
            $table->foreign('local_stock_item_id')->references('id')->on('local_stock_items')->cascadeOnDelete();
            $table->foreign('ticket_id')->references('id')->on('tickets')->nullOnDelete();
            $table->unique(['tenant_id', 'order_id', 'local_stock_item_id']);
            $table->index(['tenant_id', 'status']);
        });

        Schema::create('wallet_ledger', function (Blueprint $table): void {
            $table->string('id', 30)->primary();
            $table->string('tenant_id', 30);
            $table->string('wallet_id', 30);
            $table->string('customer_id', 30);
            $table->string('entry_type');
            $table->string('status')->default('posted');
            $table->bigInteger('amount');
            $table->string('currency', 3)->default('THB');
            $table->bigInteger('balance_after');
            $table->string('reference_type')->nullable();
            $table->string('reference_id', 34)->nullable();
            $table->string('idempotency_key', 128)->nullable();
            $table->string('created_by_admin_id', 30)->nullable();
            $table->json('metadata_json')->nullable();
            $table->timestampTz('posted_at')->nullable();
            $table->timestampsTz();

            $table->foreign('tenant_id')->references('id')->on('partner_tenants')->cascadeOnDelete();
            $table->foreign('wallet_id')->references('id')->on('wallets')->cascadeOnDelete();
            $table->foreign('customer_id')->references('id')->on('customers')->cascadeOnDelete();
            $table->foreign('created_by_admin_id')->references('id')->on('admin_users')->nullOnDelete();
            $table->unique(['tenant_id', 'wallet_id', 'idempotency_key']);
            $table->index(['tenant_id', 'wallet_id', 'created_at']);
            $table->index(['tenant_id', 'reference_type', 'reference_id']);
        });

        Schema::create('payments', function (Blueprint $table): void {
            $table->string('id', 30)->primary();
            $table->string('tenant_id', 30);
            $table->string('customer_id', 30)->nullable();
            $table->string('order_id', 30)->nullable();
            $table->string('provider');
            $table->string('status')->default('pending');
            $table->bigInteger('amount');
            $table->string('currency', 3)->default('THB');
            $table->string('reference')->nullable();
            $table->string('redirect_url')->nullable();
            $table->string('idempotency_key', 128)->nullable();
            $table->string('payload_hash', 64)->nullable();
            $table->string('provider_event_id')->nullable();
            $table->string('provider_reference')->nullable();
            $table->json('provider_payload_json')->nullable();
            $table->timestampTz('paid_at')->nullable();
            $table->timestampsTz();

            $table->foreign('tenant_id')->references('id')->on('partner_tenants')->cascadeOnDelete();
            $table->foreign('customer_id')->references('id')->on('customers')->nullOnDelete();
            $table->foreign('order_id')->references('id')->on('orders')->nullOnDelete();
            $table->unique(['provider', 'reference']);
            $table->index(['tenant_id', 'order_id']);
            $table->index(['provider', 'provider_event_id']);
            $table->index(['provider', 'provider_reference']);
        });

        Schema::create('topup_requests', function (Blueprint $table): void {
            $table->string('id', 30)->primary();
            $table->string('tenant_id', 30);
            $table->string('customer_id', 30);
            $table->string('wallet_id', 30);
            $table->string('payment_id', 30)->nullable();
            $table->string('provider')->default('manual');
            $table->string('channel');
            $table->string('status')->default('pending');
            $table->bigInteger('amount');
            $table->bigInteger('bonus_amount')->default(0);
            $table->string('currency', 3)->default('THB');
            $table->string('reference')->nullable();
            $table->timestampTz('transfer_at')->nullable();
            $table->string('slip_url')->nullable();
            $table->string('idempotency_key', 128)->nullable();
            $table->string('payload_hash', 64)->nullable();
            $table->string('reviewed_by_admin_id', 30)->nullable();
            $table->timestampTz('reviewed_at')->nullable();
            $table->text('admin_note')->nullable();
            $table->json('provider_payload_json')->nullable();
            $table->timestampsTz();

            $table->foreign('tenant_id')->references('id')->on('partner_tenants')->cascadeOnDelete();
            $table->foreign('customer_id')->references('id')->on('customers')->cascadeOnDelete();
            $table->foreign('wallet_id')->references('id')->on('wallets')->cascadeOnDelete();
            $table->foreign('payment_id')->references('id')->on('payments')->nullOnDelete();
            $table->foreign('reviewed_by_admin_id')->references('id')->on('admin_users')->nullOnDelete();
            $table->unique(['tenant_id', 'customer_id', 'idempotency_key']);
            $table->unique(['tenant_id', 'reference']);
            $table->index(['tenant_id', 'customer_id', 'status', 'created_at']);
            $table->index(['tenant_id', 'status', 'created_at']);
        });

        Schema::table('payments', function (Blueprint $table): void {
            $table->string('topup_request_id', 30)->nullable()->after('order_id');
            $table->foreign('topup_request_id')->references('id')->on('topup_requests')->nullOnDelete();
            $table->index(['tenant_id', 'topup_request_id']);
        });

        Schema::create('webhook_callbacks', function (Blueprint $table): void {
            $table->string('id', 34)->primary();
            $table->string('domain');
            $table->string('provider');
            $table->string('callback_key');
            $table->string('payload_hash', 64);
            $table->string('status')->default('accepted');
            $table->string('payment_id', 30)->nullable();
            $table->string('topup_request_id', 30)->nullable();
            $table->json('payload_json')->nullable();
            $table->json('response_json')->nullable();
            $table->timestampsTz();

            $table->foreign('payment_id')->references('id')->on('payments')->nullOnDelete();
            $table->foreign('topup_request_id')->references('id')->on('topup_requests')->nullOnDelete();
            $table->unique(['domain', 'provider', 'callback_key']);
            $table->index(['provider', 'created_at']);
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('webhook_callbacks');

        Schema::table('payments', function (Blueprint $table): void {
            $table->dropForeign(['topup_request_id']);
            $table->dropIndex(['tenant_id', 'topup_request_id']);
            $table->dropColumn('topup_request_id');
        });

        Schema::dropIfExists('topup_requests');
        Schema::dropIfExists('payments');
        Schema::dropIfExists('wallet_ledger');
        Schema::dropIfExists('order_items');
        Schema::dropIfExists('tickets');
        Schema::dropIfExists('orders');
        Schema::dropIfExists('wallets');
        Schema::dropIfExists('idempotency_keys');

        Schema::table('customer_auth_sessions', function (Blueprint $table): void {
            $table->dropColumn(['refresh_token_hash', 'refresh_expires_at', 'refreshed_from_id']);
        });

        Schema::table('customers', function (Blueprint $table): void {
            $table->dropColumn(['email', 'password_hash', 'avatar_url', 'last_login_at']);
        });
    }
};
