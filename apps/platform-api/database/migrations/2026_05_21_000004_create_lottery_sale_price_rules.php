<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Schema;
use Illuminate\Support\Str;

return new class extends Migration
{
    public function up(): void
    {
        Schema::create('game_sale_price_rules', function (Blueprint $table): void {
            $table->string('id', 30)->primary();
            $table->string('game_id', 30);
            $table->unsignedSmallInteger('set_size');
            $table->unsignedBigInteger('price_amount');
            $table->string('currency', 3)->default('THB');
            $table->string('status')->default('active');
            $table->timestampsTz();

            $table->foreign('game_id')->references('id')->on('games')->cascadeOnDelete();
            $table->unique(['game_id', 'set_size']);
            $table->index(['game_id', 'status']);
        });

        Schema::create('tenant_sale_price_overrides', function (Blueprint $table): void {
            $table->string('id', 30)->primary();
            $table->string('tenant_id', 30);
            $table->string('partner_id', 30);
            $table->string('game_id', 30);
            $table->unsignedSmallInteger('set_size');
            $table->unsignedBigInteger('price_amount');
            $table->string('currency', 3)->default('THB');
            $table->string('status')->default('active');
            $table->timestampsTz();

            $table->foreign('tenant_id')->references('id')->on('partner_tenants')->cascadeOnDelete();
            $table->foreign('partner_id')->references('id')->on('partners')->cascadeOnDelete();
            $table->foreign('game_id')->references('id')->on('games')->cascadeOnDelete();
            $table->unique(['tenant_id', 'game_id', 'set_size']);
            $table->index(['partner_id', 'game_id', 'status']);
        });

        Schema::table('order_items', function (Blueprint $table): void {
            $table->json('sale_price_rule_snapshot_json')->nullable()->after('currency');
        });

        $now = now();
        $rows = DB::table('games')->orderBy('id')->get(['id'])->map(fn (object $game): array => [
            'id' => 'gsp_'.Str::ulid()->toBase32(),
            'game_id' => (string) $game->id,
            'set_size' => 1,
            'price_amount' => 8000,
            'currency' => 'THB',
            'status' => 'active',
            'created_at' => $now,
            'updated_at' => $now,
        ])->all();

        if ($rows !== []) {
            DB::table('game_sale_price_rules')->insert($rows);
        }
    }

    public function down(): void
    {
        Schema::table('order_items', function (Blueprint $table): void {
            $table->dropColumn('sale_price_rule_snapshot_json');
        });

        Schema::dropIfExists('tenant_sale_price_overrides');
        Schema::dropIfExists('game_sale_price_rules');
    }
};
