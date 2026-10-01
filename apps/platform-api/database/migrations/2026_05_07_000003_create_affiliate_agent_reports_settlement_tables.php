<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::create('agents', function (Blueprint $table): void {
            $table->string('id', 30)->primary();
            $table->string('tenant_id', 30);
            $table->string('partner_id', 30);
            $table->string('code');
            $table->string('name');
            $table->string('phone')->nullable();
            $table->string('email')->nullable();
            $table->string('store_id')->nullable();
            $table->string('status')->default('active');
            $table->json('metadata_json')->nullable();
            $table->string('created_by_admin_id', 30)->nullable();
            $table->timestampsTz();

            $table->foreign('tenant_id')->references('id')->on('partner_tenants')->cascadeOnDelete();
            $table->foreign('partner_id')->references('id')->on('partners')->cascadeOnDelete();
            $table->foreign('created_by_admin_id')->references('id')->on('admin_users')->nullOnDelete();
            $table->unique(['tenant_id', 'code']);
            $table->index(['tenant_id', 'status']);
        });

        Schema::create('agent_quotas', function (Blueprint $table): void {
            $table->string('id', 30)->primary();
            $table->string('tenant_id', 30);
            $table->string('agent_id', 30);
            $table->string('game_id', 30)->nullable();
            $table->unsignedInteger('quota_count')->default(0);
            $table->unsignedInteger('used_count')->default(0);
            $table->string('status')->default('active');
            $table->json('payload_json')->nullable();
            $table->string('updated_by_admin_id', 30)->nullable();
            $table->timestampsTz();

            $table->foreign('tenant_id')->references('id')->on('partner_tenants')->cascadeOnDelete();
            $table->foreign('agent_id')->references('id')->on('agents')->cascadeOnDelete();
            $table->foreign('game_id')->references('id')->on('games')->nullOnDelete();
            $table->foreign('updated_by_admin_id')->references('id')->on('admin_users')->nullOnDelete();
            $table->unique(['tenant_id', 'agent_id', 'game_id']);
            $table->index(['tenant_id', 'status']);
        });

        Schema::create('affiliate_accounts', function (Blueprint $table): void {
            $table->string('id', 30)->primary();
            $table->string('tenant_id', 30);
            $table->string('customer_id', 30)->nullable();
            $table->string('code');
            $table->string('name');
            $table->string('phone')->nullable();
            $table->string('email')->nullable();
            $table->string('status')->default('active');
            $table->bigInteger('wallet_balance_amount')->default(0);
            $table->string('currency', 3)->default('THB');
            $table->json('payout_profile_json')->nullable();
            $table->json('metadata_json')->nullable();
            $table->string('created_by_admin_id', 30)->nullable();
            $table->timestampsTz();

            $table->foreign('tenant_id')->references('id')->on('partner_tenants')->cascadeOnDelete();
            $table->foreign('customer_id')->references('id')->on('customers')->nullOnDelete();
            $table->foreign('created_by_admin_id')->references('id')->on('admin_users')->nullOnDelete();
            $table->unique(['tenant_id', 'code']);
            $table->index(['tenant_id', 'status']);
            $table->index(['tenant_id', 'customer_id']);
        });

        Schema::create('affiliate_programs', function (Blueprint $table): void {
            $table->string('id', 30)->primary();
            $table->string('tenant_id', 30);
            $table->string('code');
            $table->string('name');
            $table->string('status')->default('active');
            $table->timestampTz('starts_at')->nullable();
            $table->timestampTz('ends_at')->nullable();
            $table->json('metadata_json')->nullable();
            $table->string('created_by_admin_id', 30)->nullable();
            $table->timestampsTz();

            $table->foreign('tenant_id')->references('id')->on('partner_tenants')->cascadeOnDelete();
            $table->foreign('created_by_admin_id')->references('id')->on('admin_users')->nullOnDelete();
            $table->unique(['tenant_id', 'code']);
            $table->index(['tenant_id', 'status']);
        });

        Schema::create('affiliate_links', function (Blueprint $table): void {
            $table->string('id', 30)->primary();
            $table->string('tenant_id', 30);
            $table->string('affiliate_account_id', 30);
            $table->string('affiliate_program_id', 30)->nullable();
            $table->string('code');
            $table->string('url')->nullable();
            $table->string('status')->default('active');
            $table->json('metadata_json')->nullable();
            $table->string('created_by_admin_id', 30)->nullable();
            $table->timestampsTz();

            $table->foreign('tenant_id')->references('id')->on('partner_tenants')->cascadeOnDelete();
            $table->foreign('affiliate_account_id')->references('id')->on('affiliate_accounts')->cascadeOnDelete();
            $table->foreign('affiliate_program_id')->references('id')->on('affiliate_programs')->nullOnDelete();
            $table->foreign('created_by_admin_id')->references('id')->on('admin_users')->nullOnDelete();
            $table->unique(['tenant_id', 'code']);
            $table->index(['tenant_id', 'affiliate_account_id']);
            $table->index(['tenant_id', 'status']);
        });

        Schema::create('affiliate_attributions', function (Blueprint $table): void {
            $table->string('id', 30)->primary();
            $table->string('tenant_id', 30);
            $table->string('affiliate_account_id', 30);
            $table->string('affiliate_link_id', 30)->nullable();
            $table->string('affiliate_program_id', 30)->nullable();
            $table->string('customer_id', 30)->nullable();
            $table->string('order_id', 30)->nullable();
            $table->string('status')->default('pending');
            $table->timestampTz('attributed_at')->nullable();
            $table->timestampTz('converted_at')->nullable();
            $table->json('metadata_json')->nullable();
            $table->timestampsTz();

            $table->foreign('tenant_id')->references('id')->on('partner_tenants')->cascadeOnDelete();
            $table->foreign('affiliate_account_id')->references('id')->on('affiliate_accounts')->cascadeOnDelete();
            $table->foreign('affiliate_link_id')->references('id')->on('affiliate_links')->nullOnDelete();
            $table->foreign('affiliate_program_id')->references('id')->on('affiliate_programs')->nullOnDelete();
            $table->foreign('customer_id')->references('id')->on('customers')->nullOnDelete();
            $table->foreign('order_id')->references('id')->on('orders')->nullOnDelete();
            $table->index(['tenant_id', 'affiliate_account_id', 'status']);
            $table->index(['tenant_id', 'customer_id', 'status']);
            $table->index(['tenant_id', 'order_id']);
        });

        Schema::create('commission_rules', function (Blueprint $table): void {
            $table->string('id', 30)->primary();
            $table->string('tenant_id', 30);
            $table->string('affiliate_program_id', 30)->nullable();
            $table->string('affiliate_account_id', 30)->nullable();
            $table->string('code');
            $table->string('name');
            $table->string('rule_type')->default('fixed_per_order');
            $table->bigInteger('amount')->default(0);
            $table->unsignedInteger('rate_bps')->default(0);
            $table->string('currency', 3)->default('THB');
            $table->string('status')->default('active');
            $table->json('metadata_json')->nullable();
            $table->string('created_by_admin_id', 30)->nullable();
            $table->timestampsTz();

            $table->foreign('tenant_id')->references('id')->on('partner_tenants')->cascadeOnDelete();
            $table->foreign('affiliate_program_id')->references('id')->on('affiliate_programs')->nullOnDelete();
            $table->foreign('affiliate_account_id')->references('id')->on('affiliate_accounts')->nullOnDelete();
            $table->foreign('created_by_admin_id')->references('id')->on('admin_users')->nullOnDelete();
            $table->unique(['tenant_id', 'code']);
            $table->index(['tenant_id', 'status']);
        });

        Schema::create('commission_transactions', function (Blueprint $table): void {
            $table->string('id', 30)->primary();
            $table->string('tenant_id', 30);
            $table->string('affiliate_account_id', 30);
            $table->string('affiliate_attribution_id', 30)->nullable();
            $table->string('order_id', 30);
            $table->string('commission_rule_id', 30);
            $table->string('original_commission_id', 30)->nullable();
            $table->string('transaction_type')->default('commission');
            $table->string('status')->default('calculated');
            $table->bigInteger('amount');
            $table->string('currency', 3)->default('THB');
            $table->string('idempotency_key', 128)->nullable();
            $table->string('payload_hash', 64)->nullable();
            $table->timestampTz('calculated_at')->nullable();
            $table->string('approved_by_admin_id', 30)->nullable();
            $table->timestampTz('approved_at')->nullable();
            $table->json('metadata_json')->nullable();
            $table->timestampsTz();

            $table->foreign('tenant_id')->references('id')->on('partner_tenants')->cascadeOnDelete();
            $table->foreign('affiliate_account_id')->references('id')->on('affiliate_accounts')->cascadeOnDelete();
            $table->foreign('affiliate_attribution_id')->references('id')->on('affiliate_attributions')->nullOnDelete();
            $table->foreign('order_id')->references('id')->on('orders')->cascadeOnDelete();
            $table->foreign('commission_rule_id')->references('id')->on('commission_rules')->cascadeOnDelete();
            $table->foreign('approved_by_admin_id')->references('id')->on('admin_users')->nullOnDelete();
            $table->unique(['tenant_id', 'order_id', 'commission_rule_id', 'affiliate_account_id', 'transaction_type'], 'commission_unique');
            $table->index(['tenant_id', 'status', 'created_at']);
            $table->index(['tenant_id', 'affiliate_account_id', 'status']);
        });

        Schema::create('affiliate_payouts', function (Blueprint $table): void {
            $table->string('id', 30)->primary();
            $table->string('tenant_id', 30);
            $table->string('affiliate_account_id', 30);
            $table->string('status')->default('pending');
            $table->string('payout_method')->default('bank_transfer');
            $table->bigInteger('amount');
            $table->string('currency', 3)->default('THB');
            $table->json('bank_account_json')->nullable();
            $table->text('admin_note')->nullable();
            $table->string('idempotency_key', 128)->nullable();
            $table->string('payload_hash', 64)->nullable();
            $table->string('requested_by_admin_id', 30)->nullable();
            $table->string('approved_by_admin_id', 30)->nullable();
            $table->timestampTz('approved_at')->nullable();
            $table->timestampsTz();

            $table->foreign('tenant_id')->references('id')->on('partner_tenants')->cascadeOnDelete();
            $table->foreign('affiliate_account_id')->references('id')->on('affiliate_accounts')->cascadeOnDelete();
            $table->foreign('requested_by_admin_id')->references('id')->on('admin_users')->nullOnDelete();
            $table->foreign('approved_by_admin_id')->references('id')->on('admin_users')->nullOnDelete();
            $table->index(['tenant_id', 'status', 'created_at']);
            $table->index(['tenant_id', 'affiliate_account_id', 'status']);
        });

        Schema::create('report_export_jobs', function (Blueprint $table): void {
            $table->string('id', 30)->primary();
            $table->string('scope');
            $table->string('tenant_id', 30)->nullable();
            $table->string('requested_by_admin_id', 30);
            $table->string('source')->default('report');
            $table->string('report_key')->nullable();
            $table->string('format');
            $table->string('status')->default('ready');
            $table->unsignedTinyInteger('progress_percent')->default(100);
            $table->string('download_url')->nullable();
            $table->string('error_code')->nullable();
            $table->timestampTz('expires_at')->nullable();
            $table->string('idempotency_key', 128)->nullable();
            $table->string('payload_hash', 64)->nullable();
            $table->json('filters_json')->nullable();
            $table->timestampsTz();

            $table->foreign('tenant_id')->references('id')->on('partner_tenants')->nullOnDelete();
            $table->foreign('requested_by_admin_id')->references('id')->on('admin_users')->cascadeOnDelete();
            $table->index(['scope', 'tenant_id', 'status']);
            $table->index(['requested_by_admin_id', 'idempotency_key']);
        });

        Schema::create('partner_settlements', function (Blueprint $table): void {
            $table->string('id', 30)->primary();
            $table->string('partner_id', 30);
            $table->string('tenant_id', 30);
            $table->string('status')->default('draft');
            $table->bigInteger('sales_amount')->default(0);
            $table->bigInteger('commission_amount')->default(0);
            $table->bigInteger('payout_amount')->default(0);
            $table->bigInteger('net_amount')->default(0);
            $table->string('currency', 3)->default('THB');
            $table->date('period_from')->nullable();
            $table->date('period_to')->nullable();
            $table->string('approved_by_admin_id', 30)->nullable();
            $table->timestampTz('approved_at')->nullable();
            $table->string('idempotency_key', 128)->nullable();
            $table->string('payload_hash', 64)->nullable();
            $table->json('summary_json')->nullable();
            $table->timestampsTz();

            $table->foreign('partner_id')->references('id')->on('partners')->cascadeOnDelete();
            $table->foreign('tenant_id')->references('id')->on('partner_tenants')->cascadeOnDelete();
            $table->foreign('approved_by_admin_id')->references('id')->on('admin_users')->nullOnDelete();
            $table->unique(['partner_id', 'tenant_id', 'period_from', 'period_to']);
            $table->index(['partner_id', 'status']);
            $table->index(['tenant_id', 'status']);
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('partner_settlements');
        Schema::dropIfExists('report_export_jobs');
        Schema::dropIfExists('affiliate_payouts');
        Schema::dropIfExists('commission_transactions');
        Schema::dropIfExists('commission_rules');
        Schema::dropIfExists('affiliate_attributions');
        Schema::dropIfExists('affiliate_links');
        Schema::dropIfExists('affiliate_programs');
        Schema::dropIfExists('affiliate_accounts');
        Schema::dropIfExists('agent_quotas');
        Schema::dropIfExists('agents');
    }
};
