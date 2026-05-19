<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::create('virtual_stock_supply_layers', function (Blueprint $table): void {
            $table->string('id', 30)->primary();
            $table->string('profile_id', 30);
            $table->string('batch_id', 30);
            $table->string('game_id', 30);
            $table->string('status')->default('active');
            $table->string('layer_seed', 128);
            $table->unsignedBigInteger('base_count')->default(1000000);
            $table->unsignedBigInteger('total_capacity')->default(1000000);
            $table->json('set_distribution_json')->nullable();
            $table->string('created_by_admin_id', 30)->nullable();
            $table->timestampsTz();

            $table->foreign('profile_id')->references('id')->on('stock_supply_profiles')->cascadeOnDelete();
            $table->foreign('batch_id')->references('id')->on('stock_generation_batches')->cascadeOnDelete();
            $table->foreign('game_id')->references('id')->on('games')->cascadeOnDelete();
            $table->foreign('created_by_admin_id')->references('id')->on('admin_users')->nullOnDelete();
            $table->unique('batch_id', 'virtual_stock_supply_layers_batch_unique');
            $table->index(['game_id', 'status'], 'virtual_stock_supply_layers_game_status_index');
            $table->index(['profile_id', 'status'], 'virtual_stock_supply_layers_profile_status_index');
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('virtual_stock_supply_layers');
    }
};
