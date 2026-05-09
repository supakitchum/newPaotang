<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::create('partner_billing_plans', function (Blueprint $table): void {
            $table->string('id', 30)->primary();
            $table->string('code')->unique();
            $table->string('name');
            $table->string('status')->default('active');
            $table->unsignedBigInteger('monthly_fee_amount')->default(0);
            $table->string('currency', 3)->default('THB');
            $table->json('features_json')->nullable();
            $table->json('limits_json')->nullable();
            $table->timestampsTz();

            $table->index(['status']);
        });

        Schema::create('platform_system_settings', function (Blueprint $table): void {
            $table->string('id', 30)->primary();
            $table->string('key')->unique();
            $table->json('value_json')->nullable();
            $table->string('status')->default('active');
            $table->timestampsTz();

            $table->index(['status']);
        });

        Schema::create('tenant_price_rules', function (Blueprint $table): void {
            $table->string('id', 30)->primary();
            $table->string('tenant_id', 30);
            $table->string('game_id', 30)->nullable();
            $table->string('code');
            $table->string('name');
            $table->string('rule_type')->default('fixed_price');
            $table->unsignedBigInteger('price_amount')->default(0);
            $table->string('currency', 3)->default('THB');
            $table->string('status')->default('active');
            $table->json('conditions_json')->nullable();
            $table->timestampsTz();

            $table->foreign('tenant_id')->references('id')->on('partner_tenants')->cascadeOnDelete();
            $table->foreign('game_id')->references('id')->on('games')->nullOnDelete();
            $table->unique(['tenant_id', 'code']);
            $table->index(['tenant_id', 'status']);
            $table->index(['tenant_id', 'game_id']);
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('tenant_price_rules');
        Schema::dropIfExists('platform_system_settings');
        Schema::dropIfExists('partner_billing_plans');
    }
};
