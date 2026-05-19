<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::create('stock_sale_limit_overrides', function (Blueprint $table): void {
            $table->string('id', 40)->primary();
            $table->string('game_id', 30);
            $table->string('scope_type');
            $table->string('scope_id', 30);
            $table->string('dimension');
            $table->string('value', 32);
            $table->unsignedInteger('limit');
            $table->timestampsTz();

            $table->foreign('game_id')->references('id')->on('games')->cascadeOnDelete();
            $table->unique(['game_id', 'scope_type', 'scope_id', 'dimension', 'value'], 'stock_sale_limit_overrides_key_unique');
            $table->index(['scope_type', 'scope_id'], 'stock_sale_limit_overrides_scope_index');
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('stock_sale_limit_overrides');
    }
};
