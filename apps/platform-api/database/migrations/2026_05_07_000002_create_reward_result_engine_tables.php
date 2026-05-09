<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::create('reward_results', function (Blueprint $table): void {
            $table->string('id', 30)->primary();
            $table->string('game_id', 30);
            $table->string('status')->default('recorded');
            $table->unsignedInteger('version')->default(1);
            $table->json('summary_json')->nullable();
            $table->string('created_by_admin_id', 30)->nullable();
            $table->string('verified_by_admin_id', 30)->nullable();
            $table->string('published_by_admin_id', 30)->nullable();
            $table->string('corrected_by_admin_id', 30)->nullable();
            $table->text('correction_note')->nullable();
            $table->timestampTz('checked_at')->nullable();
            $table->timestampTz('verified_at')->nullable();
            $table->timestampTz('published_at')->nullable();
            $table->timestampTz('corrected_at')->nullable();
            $table->timestampsTz();

            $table->foreign('game_id')->references('id')->on('games')->cascadeOnDelete();
            $table->foreign('created_by_admin_id')->references('id')->on('admin_users')->nullOnDelete();
            $table->foreign('verified_by_admin_id')->references('id')->on('admin_users')->nullOnDelete();
            $table->foreign('published_by_admin_id')->references('id')->on('admin_users')->nullOnDelete();
            $table->foreign('corrected_by_admin_id')->references('id')->on('admin_users')->nullOnDelete();
            $table->unique('game_id');
            $table->index(['status', 'created_at']);
            $table->index(['game_id', 'status']);
        });

        Schema::create('reward_prizes', function (Blueprint $table): void {
            $table->string('id', 30)->primary();
            $table->string('reward_result_id', 30);
            $table->string('game_id', 30);
            $table->string('prize_type');
            $table->string('prize_number', 32);
            $table->bigInteger('amount');
            $table->string('currency', 3)->default('THB');
            $table->unsignedInteger('sort_order')->default(0);
            $table->timestampsTz();

            $table->foreign('reward_result_id')->references('id')->on('reward_results')->cascadeOnDelete();
            $table->foreign('game_id')->references('id')->on('games')->cascadeOnDelete();
            $table->unique(['reward_result_id', 'prize_type', 'prize_number'], 'reward_prize_unique');
            $table->index(['game_id', 'prize_type', 'prize_number']);
        });

        Schema::create('reward_check_batches', function (Blueprint $table): void {
            $table->string('id', 30)->primary();
            $table->string('reward_result_id', 30);
            $table->string('game_id', 30);
            $table->string('status')->default('pending');
            $table->unsignedInteger('chunk_count')->default(0);
            $table->unsignedInteger('processed_ticket_count')->default(0);
            $table->unsignedInteger('winning_count')->default(0);
            $table->string('idempotency_key', 128)->nullable();
            $table->string('payload_hash', 64)->nullable();
            $table->timestampTz('started_at')->nullable();
            $table->timestampTz('completed_at')->nullable();
            $table->timestampsTz();

            $table->foreign('reward_result_id')->references('id')->on('reward_results')->cascadeOnDelete();
            $table->foreign('game_id')->references('id')->on('games')->cascadeOnDelete();
            $table->index(['reward_result_id', 'status']);
            $table->index(['game_id', 'status']);
        });

        Schema::create('reward_check_items', function (Blueprint $table): void {
            $table->string('id', 30)->primary();
            $table->string('reward_check_batch_id', 30);
            $table->string('reward_result_id', 30);
            $table->string('tenant_id', 30)->nullable();
            $table->string('cursor_from', 64)->nullable();
            $table->string('cursor_to', 64)->nullable();
            $table->string('status')->default('pending');
            $table->unsignedInteger('checked_count')->default(0);
            $table->unsignedInteger('winning_count')->default(0);
            $table->timestampsTz();

            $table->foreign('reward_check_batch_id')->references('id')->on('reward_check_batches')->cascadeOnDelete();
            $table->foreign('reward_result_id')->references('id')->on('reward_results')->cascadeOnDelete();
            $table->foreign('tenant_id')->references('id')->on('partner_tenants')->nullOnDelete();
            $table->index(['reward_result_id', 'status']);
            $table->index(['tenant_id', 'status']);
        });

        Schema::create('winning_tickets', function (Blueprint $table): void {
            $table->string('id', 30)->primary();
            $table->string('tenant_id', 30);
            $table->string('game_id', 30);
            $table->string('ticket_id', 30);
            $table->string('reward_result_id', 30);
            $table->string('reward_prize_id', 30);
            $table->string('prize_type');
            $table->string('prize_number', 32);
            $table->bigInteger('amount');
            $table->string('currency', 3)->default('THB');
            $table->string('status')->default('pending');
            $table->timestampsTz();

            $table->foreign('tenant_id')->references('id')->on('partner_tenants')->cascadeOnDelete();
            $table->foreign('game_id')->references('id')->on('games')->cascadeOnDelete();
            $table->foreign('ticket_id')->references('id')->on('tickets')->cascadeOnDelete();
            $table->foreign('reward_result_id')->references('id')->on('reward_results')->cascadeOnDelete();
            $table->foreign('reward_prize_id')->references('id')->on('reward_prizes')->cascadeOnDelete();
            $table->unique(['game_id', 'ticket_id', 'prize_type', 'prize_number'], 'winning_ticket_unique');
            $table->index(['tenant_id', 'ticket_id']);
            $table->index(['reward_result_id', 'status']);
        });

        Schema::create('reward_publish_logs', function (Blueprint $table): void {
            $table->string('id', 30)->primary();
            $table->string('reward_result_id', 30);
            $table->string('game_id', 30);
            $table->unsignedInteger('reward_version');
            $table->string('published_by_admin_id', 30)->nullable();
            $table->json('payload_json')->nullable();
            $table->timestampTz('published_at');
            $table->timestampsTz();

            $table->foreign('reward_result_id')->references('id')->on('reward_results')->cascadeOnDelete();
            $table->foreign('game_id')->references('id')->on('games')->cascadeOnDelete();
            $table->foreign('published_by_admin_id')->references('id')->on('admin_users')->nullOnDelete();
            $table->unique(['reward_result_id', 'reward_version']);
            $table->index(['game_id', 'published_at']);
        });

        Schema::create('reward_claims', function (Blueprint $table): void {
            $table->string('id', 30)->primary();
            $table->string('tenant_id', 30);
            $table->string('customer_id', 30);
            $table->string('ticket_id', 30);
            $table->string('winning_ticket_id', 30);
            $table->string('game_id', 30);
            $table->string('wallet_id', 30)->nullable();
            $table->string('payout_ledger_id', 30)->nullable();
            $table->string('reference')->nullable();
            $table->string('status')->default('submitted');
            $table->string('payout_method');
            $table->bigInteger('prize_amount');
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
            $table->foreign('customer_id')->references('id')->on('customers')->cascadeOnDelete();
            $table->foreign('ticket_id')->references('id')->on('tickets')->cascadeOnDelete();
            $table->foreign('winning_ticket_id')->references('id')->on('winning_tickets')->cascadeOnDelete();
            $table->foreign('game_id')->references('id')->on('games')->cascadeOnDelete();
            $table->foreign('wallet_id')->references('id')->on('wallets')->nullOnDelete();
            $table->foreign('payout_ledger_id')->references('id')->on('wallet_ledger')->nullOnDelete();
            $table->foreign('reviewed_by_admin_id')->references('id')->on('admin_users')->nullOnDelete();
            $table->foreign('paid_by_admin_id')->references('id')->on('admin_users')->nullOnDelete();
            $table->unique(['tenant_id', 'winning_ticket_id']);
            $table->unique(['tenant_id', 'customer_id', 'idempotency_key'], 'reward_claim_idem_unique');
            $table->index(['tenant_id', 'status', 'created_at']);
            $table->index(['tenant_id', 'customer_id', 'created_at']);
            $table->index(['tenant_id', 'game_id', 'status']);
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('reward_claims');
        Schema::dropIfExists('reward_publish_logs');
        Schema::dropIfExists('winning_tickets');
        Schema::dropIfExists('reward_check_items');
        Schema::dropIfExists('reward_check_batches');
        Schema::dropIfExists('reward_prizes');
        Schema::dropIfExists('reward_results');
    }
};
