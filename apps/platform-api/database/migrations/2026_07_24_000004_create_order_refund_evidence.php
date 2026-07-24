<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::create('order_refunds', function (Blueprint $table): void {
            $table->string('id', 30)->primary();
            $table->string('tenant_id', 30);
            $table->string('order_id', 30);
            $table->string('payment_id', 30)->nullable();
            $table->string('method', 32);
            $table->bigInteger('amount');
            $table->string('currency', 3);
            $table->string('external_reference', 191)->nullable();
            $table->string('wallet_ledger_id', 30)->nullable();
            $table->text('reason');
            $table->string('processed_by_admin_id', 30)->nullable();
            $table->string('idempotency_key', 128);
            $table->timestampsTz();

            $table->foreign('tenant_id')->references('id')->on('partner_tenants')->cascadeOnDelete();
            $table->foreign('order_id')->references('id')->on('orders');
            $table->foreign('payment_id')->references('id')->on('payments');
            $table->foreign('wallet_ledger_id')->references('id')->on('wallet_ledger');
            $table->foreign('processed_by_admin_id')->references('id')->on('admin_users')->nullOnDelete();
            $table->unique(['tenant_id', 'order_id'], 'order_refunds_tenant_order_unique');
            $table->unique(
                ['tenant_id', 'method', 'external_reference'],
                'order_refunds_external_reference_unique',
            );
            $table->unique(
                ['tenant_id', 'processed_by_admin_id', 'idempotency_key'],
                'order_refunds_admin_idempotency_unique',
            );
            $table->index(['tenant_id', 'created_at']);
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('order_refunds');
    }
};
