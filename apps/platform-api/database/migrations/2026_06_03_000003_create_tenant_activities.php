<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::create('tenant_activities', function (Blueprint $table): void {
            $table->string('id', 30)->primary();
            $table->string('tenant_id', 30);
            $table->string('game_id', 30);
            $table->string('name');
            $table->string('slug');
            $table->string('type');
            $table->string('status')->default('draft');
            $table->integer('sort_order')->default(0);
            $table->string('image_full_asset_id', 30)->nullable();
            $table->string('image_thumb_asset_id', 30)->nullable();
            $table->json('metadata_json')->nullable();
            $table->timestampsTz();

            $table->foreign('tenant_id')->references('id')->on('partner_tenants')->cascadeOnDelete();
            $table->foreign('game_id')->references('id')->on('games')->cascadeOnDelete();
            $table->foreign('image_full_asset_id')->references('id')->on('platform_assets')->nullOnDelete();
            $table->foreign('image_thumb_asset_id')->references('id')->on('platform_assets')->nullOnDelete();
            $table->unique(['tenant_id', 'slug']);
            $table->index(['tenant_id', 'game_id', 'type', 'status']);
            $table->index(['tenant_id', 'status', 'sort_order']);
        });

        Schema::create('tenant_activity_lucky_configs', function (Blueprint $table): void {
            $table->string('activity_id', 30)->primary();
            $table->boolean('first_prize_last2_enabled')->default(true);
            $table->boolean('first_prize_last3_enabled')->default(false);
            $table->boolean('last2_enabled')->default(false);
            $table->string('eligibility_rule')->default('cumulative_tickets');
            $table->unsignedInteger('threshold_tickets')->default(1);
            $table->bigInteger('first_prize_last2_amount')->default(0);
            $table->bigInteger('first_prize_last3_amount')->default(0);
            $table->bigInteger('last2_amount')->default(0);
            $table->string('currency', 3)->default('THB');
            $table->json('metadata_json')->nullable();
            $table->timestampsTz();

            $table->foreign('activity_id')->references('id')->on('tenant_activities')->cascadeOnDelete();
            $table->index(['eligibility_rule', 'threshold_tickets']);
        });

        Schema::create('tenant_activity_cashback_configs', function (Blueprint $table): void {
            $table->string('activity_id', 30)->primary();
            $table->string('cashback_type')->default('percent');
            $table->unsignedInteger('cashback_percent_bps')->default(0);
            $table->bigInteger('fixed_amount')->default(0);
            $table->unsignedInteger('min_ticket_count')->default(0);
            $table->bigInteger('min_purchase_amount')->default(0);
            $table->string('currency', 3)->default('THB');
            $table->json('metadata_json')->nullable();
            $table->timestampsTz();

            $table->foreign('activity_id')->references('id')->on('tenant_activities')->cascadeOnDelete();
            $table->index(['cashback_type']);
        });

        Schema::create('tenant_activity_entries', function (Blueprint $table): void {
            $table->string('id', 30)->primary();
            $table->string('tenant_id', 30);
            $table->string('activity_id', 30);
            $table->string('game_id', 30);
            $table->string('customer_id', 30);
            $table->string('prediction_type');
            $table->string('selected_number', 6);
            $table->string('status')->default('submitted');
            $table->string('rights_rule')->nullable();
            $table->string('rights_source_type')->nullable();
            $table->string('rights_source_id', 30)->nullable();
            $table->timestampTz('awarded_at')->nullable();
            $table->json('metadata_json')->nullable();
            $table->timestampsTz();

            $table->foreign('tenant_id')->references('id')->on('partner_tenants')->cascadeOnDelete();
            $table->foreign('activity_id')->references('id')->on('tenant_activities')->cascadeOnDelete();
            $table->foreign('game_id')->references('id')->on('games')->cascadeOnDelete();
            $table->foreign('customer_id')->references('id')->on('customers')->cascadeOnDelete();
            $table->unique(['tenant_id', 'activity_id', 'customer_id', 'prediction_type', 'selected_number'], 'tenant_activity_entry_unique');
            $table->index(['tenant_id', 'game_id', 'status']);
            $table->index(['activity_id', 'customer_id', 'created_at']);
        });

        Schema::create('tenant_activity_awards', function (Blueprint $table): void {
            $table->string('id', 30)->primary();
            $table->string('tenant_id', 30);
            $table->string('activity_id', 30);
            $table->string('game_id', 30);
            $table->string('customer_id', 30);
            $table->string('entry_id', 30)->nullable();
            $table->string('type');
            $table->string('prediction_type')->nullable();
            $table->bigInteger('amount');
            $table->string('currency', 3)->default('THB');
            $table->string('status')->default('claimable');
            $table->timestampTz('calculated_at')->nullable();
            $table->json('metadata_json')->nullable();
            $table->timestampsTz();

            $table->foreign('tenant_id')->references('id')->on('partner_tenants')->cascadeOnDelete();
            $table->foreign('activity_id')->references('id')->on('tenant_activities')->cascadeOnDelete();
            $table->foreign('game_id')->references('id')->on('games')->cascadeOnDelete();
            $table->foreign('customer_id')->references('id')->on('customers')->cascadeOnDelete();
            $table->foreign('entry_id')->references('id')->on('tenant_activity_entries')->nullOnDelete();
            $table->unique(['tenant_id', 'entry_id'], 'tenant_activity_award_entry_unique');
            $table->index(['tenant_id', 'game_id', 'status']);
            $table->index(['activity_id', 'type', 'status']);
        });

        Schema::create('activity_claims', function (Blueprint $table): void {
            $table->string('id', 30)->primary();
            $table->string('tenant_id', 30);
            $table->string('activity_award_id', 30);
            $table->string('activity_id', 30);
            $table->string('game_id', 30);
            $table->string('customer_id', 30);
            $table->string('wallet_id', 30)->nullable();
            $table->string('payout_ledger_id', 30)->nullable();
            $table->string('reference')->nullable();
            $table->string('status')->default('submitted');
            $table->string('payout_method');
            $table->bigInteger('claim_amount');
            $table->string('currency', 3)->default('THB');
            $table->json('bank_account_json')->nullable();
            $table->text('customer_note')->nullable();
            $table->text('admin_note')->nullable();
            $table->string('idempotency_key', 128)->nullable();
            $table->string('payload_hash', 64)->nullable();
            $table->string('reviewed_by_admin_id', 30)->nullable();
            $table->string('paid_by_admin_id', 30)->nullable();
            $table->timestampTz('submitted_at')->nullable();
            $table->timestampTz('reviewed_at')->nullable();
            $table->timestampTz('paid_at')->nullable();
            $table->timestampsTz();

            $table->foreign('tenant_id')->references('id')->on('partner_tenants')->cascadeOnDelete();
            $table->foreign('activity_award_id')->references('id')->on('tenant_activity_awards')->cascadeOnDelete();
            $table->foreign('activity_id')->references('id')->on('tenant_activities')->cascadeOnDelete();
            $table->foreign('game_id')->references('id')->on('games')->cascadeOnDelete();
            $table->foreign('customer_id')->references('id')->on('customers')->cascadeOnDelete();
            $table->foreign('wallet_id')->references('id')->on('wallets')->nullOnDelete();
            $table->foreign('payout_ledger_id')->references('id')->on('wallet_ledger')->nullOnDelete();
            $table->foreign('reviewed_by_admin_id')->references('id')->on('admin_users')->nullOnDelete();
            $table->foreign('paid_by_admin_id')->references('id')->on('admin_users')->nullOnDelete();
            $table->index(['tenant_id', 'activity_award_id']);
            $table->unique(['tenant_id', 'customer_id', 'idempotency_key'], 'activity_claim_idem_unique');
            $table->index(['tenant_id', 'status', 'created_at']);
            $table->index(['tenant_id', 'game_id', 'status']);
            $table->index(['tenant_id', 'customer_id', 'created_at']);
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('activity_claims');
        Schema::dropIfExists('tenant_activity_awards');
        Schema::dropIfExists('tenant_activity_entries');
        Schema::dropIfExists('tenant_activity_cashback_configs');
        Schema::dropIfExists('tenant_activity_lucky_configs');
        Schema::dropIfExists('tenant_activities');
    }
};
