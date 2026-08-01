<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::create('tenant_reward_risk_settings', function (Blueprint $table): void {
            $table->string('id', 30)->primary();
            $table->string('tenant_id', 30)->unique();
            $table->boolean('enabled')->default(false);
            $table->json('monitored_prize_types_json')->nullable();
            $table->decimal('threshold_multiplier', 8, 2)->default(1);
            $table->unsignedInteger('version')->default(1);
            $table->string('updated_by_admin_id', 30)->nullable();
            $table->timestampsTz();

            $table->foreign('tenant_id')->references('id')->on('partner_tenants')->cascadeOnDelete();
            $table->foreign('updated_by_admin_id')->references('id')->on('admin_users')->nullOnDelete();
            $table->index(['enabled', 'updated_at'], 'tenant_reward_risk_settings_enabled_idx');
        });

        Schema::create('reward_risk_runs', function (Blueprint $table): void {
            $table->string('id', 30)->primary();
            $table->string('tenant_id', 30);
            $table->string('game_id', 30);
            $table->string('reward_result_id', 30)->nullable();
            $table->string('phase', 24);
            $table->unsignedInteger('reward_version')->default(1);
            $table->string('source_hash', 64);
            $table->json('settings_snapshot_json');
            $table->string('status', 24)->default('queued');
            $table->boolean('is_current')->default(true);
            $table->unsignedInteger('evaluated_group_count')->default(0);
            $table->unsignedInteger('finding_count')->default(0);
            $table->bigInteger('total_purchase_amount')->default(0);
            $table->bigInteger('total_prize_amount')->default(0);
            $table->string('currency', 3)->default('THB');
            $table->text('last_error')->nullable();
            $table->timestampTz('started_at')->nullable();
            $table->timestampTz('completed_at')->nullable();
            $table->timestampTz('superseded_at')->nullable();
            $table->timestampsTz();

            $table->foreign('tenant_id')->references('id')->on('partner_tenants')->cascadeOnDelete();
            $table->foreign('game_id')->references('id')->on('games')->cascadeOnDelete();
            $table->foreign('reward_result_id')->references('id')->on('reward_results')->nullOnDelete();
            $table->unique(['tenant_id', 'reward_result_id', 'phase', 'source_hash'], 'reward_risk_run_source_unique');
            $table->index(['tenant_id', 'game_id', 'phase', 'is_current'], 'reward_risk_run_tenant_game_idx');
            $table->index(['status', 'created_at'], 'reward_risk_run_status_idx');
        });

        Schema::create('reward_risk_findings', function (Blueprint $table): void {
            $table->string('id', 30)->primary();
            $table->string('run_id', 30);
            $table->string('tenant_id', 30);
            $table->string('game_id', 30);
            $table->string('customer_id', 30)->nullable();
            $table->string('full_number', 32);
            $table->json('prize_types_json');
            $table->unsignedInteger('ticket_count')->default(0);
            $table->bigInteger('purchase_amount')->default(0);
            $table->bigInteger('prize_amount')->default(0);
            $table->decimal('threshold_multiplier', 8, 2);
            $table->bigInteger('threshold_amount')->default(0);
            $table->bigInteger('excess_amount')->default(0);
            $table->string('currency', 3)->default('THB');
            $table->string('status', 32)->default('threshold_exceeded');
            $table->timestampsTz();

            $table->foreign('run_id')->references('id')->on('reward_risk_runs')->cascadeOnDelete();
            $table->foreign('tenant_id')->references('id')->on('partner_tenants')->cascadeOnDelete();
            $table->foreign('game_id')->references('id')->on('games')->cascadeOnDelete();
            $table->foreign('customer_id')->references('id')->on('customers')->nullOnDelete();
            $table->unique(['run_id', 'customer_id', 'full_number'], 'reward_risk_finding_group_unique');
            $table->index(['tenant_id', 'game_id', 'status', 'id'], 'reward_risk_finding_tenant_idx');
            $table->index(['customer_id', 'game_id'], 'reward_risk_finding_customer_idx');
        });

        Schema::create('reward_risk_finding_tickets', function (Blueprint $table): void {
            $table->string('id', 30)->primary();
            $table->string('finding_id', 30);
            $table->string('run_id', 30);
            $table->string('tenant_id', 30);
            $table->string('ticket_id', 30)->nullable();
            $table->string('winning_ticket_id', 30)->nullable();
            $table->string('prize_type');
            $table->string('prize_number', 32);
            $table->bigInteger('amount');
            $table->string('currency', 3)->default('THB');
            $table->timestampsTz();

            $table->foreign('finding_id')->references('id')->on('reward_risk_findings')->cascadeOnDelete();
            $table->foreign('run_id')->references('id')->on('reward_risk_runs')->cascadeOnDelete();
            $table->foreign('tenant_id')->references('id')->on('partner_tenants')->cascadeOnDelete();
            $table->foreign('ticket_id')->references('id')->on('tickets')->nullOnDelete();
            $table->foreign('winning_ticket_id')->references('id')->on('winning_tickets')->nullOnDelete();
            $table->unique(['finding_id', 'ticket_id', 'prize_type', 'prize_number'], 'reward_risk_finding_ticket_unique');
            $table->index(['tenant_id', 'ticket_id'], 'reward_risk_finding_ticket_tenant_idx');
        });

        Schema::table('orders', function (Blueprint $table): void {
            $table->index(['tenant_id', 'game_id', 'customer_id', 'payment_status'], 'orders_reward_risk_paid_idx');
        });
        Schema::table('tickets', function (Blueprint $table): void {
            $table->index(['tenant_id', 'game_id', 'customer_id', 'full_number'], 'tickets_reward_risk_group_idx');
        });
    }

    public function down(): void
    {
        Schema::table('tickets', fn (Blueprint $table) => $table->dropIndex('tickets_reward_risk_group_idx'));
        Schema::table('orders', fn (Blueprint $table) => $table->dropIndex('orders_reward_risk_paid_idx'));
        Schema::dropIfExists('reward_risk_finding_tickets');
        Schema::dropIfExists('reward_risk_findings');
        Schema::dropIfExists('reward_risk_runs');
        Schema::dropIfExists('tenant_reward_risk_settings');
    }
};
