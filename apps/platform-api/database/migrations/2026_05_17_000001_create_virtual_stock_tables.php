<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::create('base_lottery_numbers', function (Blueprint $table): void {
            $table->string('full_number', 6)->primary();
            $table->string('front3', 3);
            $table->string('back3', 3);
            $table->string('back2', 2);
            $table->timestampsTz();

            $table->index('front3');
            $table->index('back3');
            $table->index('back2');
        });

        Schema::create('stock_supply_profiles', function (Blueprint $table): void {
            $table->string('id', 30)->primary();
            $table->string('game_id', 30);
            $table->string('status')->default('active');
            $table->string('seed', 128);
            $table->unsignedBigInteger('base_count')->default(1000000);
            $table->unsignedBigInteger('total_capacity')->default(1000000);
            $table->json('set_distribution_json')->nullable();
            $table->string('created_by_admin_id', 30)->nullable();
            $table->timestampsTz();

            $table->foreign('game_id')->references('id')->on('games')->cascadeOnDelete();
            $table->foreign('created_by_admin_id')->references('id')->on('admin_users')->nullOnDelete();
            $table->index(['game_id', 'status'], 'stock_supply_profiles_game_status_index');
            $table->index(['game_id', 'created_at']);
        });

        Schema::create('stock_partner_distributions', function (Blueprint $table): void {
            $table->string('id', 30)->primary();
            $table->string('game_id', 30);
            $table->string('partner_id', 30);
            $table->string('tenant_id', 30)->nullable();
            $table->unsignedInteger('percent_basis_points')->default(0);
            $table->string('status')->default('active');
            $table->timestampsTz();

            $table->foreign('game_id')->references('id')->on('games')->cascadeOnDelete();
            $table->foreign('partner_id')->references('id')->on('partners')->cascadeOnDelete();
            $table->foreign('tenant_id')->references('id')->on('partner_tenants')->nullOnDelete();
            $table->unique(['game_id', 'partner_id'], 'stock_partner_distributions_game_partner_unique');
            $table->index(['game_id', 'status']);
        });

        Schema::create('stock_sale_limit_settings', function (Blueprint $table): void {
            $table->string('id', 30)->primary();
            $table->string('game_id', 30);
            $table->string('scope_type');
            $table->string('scope_id', 30);
            $table->unsignedInteger('back2_limit')->nullable();
            $table->unsignedInteger('back3_limit')->nullable();
            $table->unsignedInteger('front3_limit')->nullable();
            $table->timestampsTz();

            $table->foreign('game_id')->references('id')->on('games')->cascadeOnDelete();
            $table->unique(['game_id', 'scope_type', 'scope_id'], 'stock_sale_limits_scope_unique');
            $table->index(['scope_type', 'scope_id']);
        });

        Schema::create('virtual_stock_counters', function (Blueprint $table): void {
            $table->string('id', 40)->primary();
            $table->string('game_id', 30);
            $table->string('scope_type');
            $table->string('scope_id', 30);
            $table->string('dimension');
            $table->string('value', 32);
            $table->unsignedInteger('reserved_count')->default(0);
            $table->unsignedInteger('sold_count')->default(0);
            $table->timestampsTz();

            $table->foreign('game_id')->references('id')->on('games')->cascadeOnDelete();
            $table->unique(['game_id', 'scope_type', 'scope_id', 'dimension', 'value'], 'virtual_stock_counters_key_unique');
            $table->index(['game_id', 'dimension', 'value']);
        });

        Schema::table('stock_items', function (Blueprint $table): void {
            $table->string('virtual_stock_ref', 160)->nullable()->after('allocation_id');
            $table->unsignedInteger('virtual_copy_index')->nullable()->after('virtual_stock_ref');
            $table->index(['game_id', 'virtual_stock_ref'], 'stock_items_virtual_ref_index');
        });

        Schema::table('local_stock_items', function (Blueprint $table): void {
            $table->string('virtual_stock_ref', 160)->nullable()->after('allocation_id');
            $table->unsignedInteger('virtual_copy_index')->nullable()->after('virtual_stock_ref');
            $table->index(['tenant_id', 'game_id', 'virtual_stock_ref'], 'local_stock_items_virtual_ref_index');
        });
    }

    public function down(): void
    {
        Schema::table('local_stock_items', function (Blueprint $table): void {
            $table->dropIndex('local_stock_items_virtual_ref_index');
            $table->dropColumn(['virtual_stock_ref', 'virtual_copy_index']);
        });

        Schema::table('stock_items', function (Blueprint $table): void {
            $table->dropIndex('stock_items_virtual_ref_index');
            $table->dropColumn(['virtual_stock_ref', 'virtual_copy_index']);
        });

        Schema::dropIfExists('virtual_stock_counters');
        Schema::dropIfExists('stock_sale_limit_settings');
        Schema::dropIfExists('stock_partner_distributions');
        Schema::dropIfExists('stock_supply_profiles');
        Schema::dropIfExists('base_lottery_numbers');
    }
};
