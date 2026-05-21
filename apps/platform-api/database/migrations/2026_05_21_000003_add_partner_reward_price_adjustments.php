<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::table('tenant_price_rules', function (Blueprint $table): void {
            $table->string('base_source')->default('central_reward')->index();
            $table->bigInteger('adjustment_amount')->default(0);
            $table->integer('adjustment_bps')->nullable();
        });

        DB::table('tenant_price_rules')->update([
            'base_source' => 'central_reward',
            'adjustment_amount' => DB::raw('price_amount'),
        ]);

        Schema::table('winning_tickets', function (Blueprint $table): void {
            $table->bigInteger('base_amount')->nullable();
            $table->bigInteger('adjustment_amount')->default(0);
            $table->string('tenant_price_rule_id', 30)->nullable()->index();
            $table->json('price_rule_snapshot_json')->nullable();
        });

        DB::table('winning_tickets')->update([
            'base_amount' => DB::raw('amount'),
        ]);

        Schema::table('reward_claims', function (Blueprint $table): void {
            $table->bigInteger('base_prize_amount')->nullable();
            $table->bigInteger('adjustment_amount')->default(0);
            $table->string('tenant_price_rule_id', 30)->nullable()->index();
            $table->json('price_rule_snapshot_json')->nullable();
        });

        DB::table('reward_claims')->update([
            'base_prize_amount' => DB::raw('prize_amount'),
        ]);
    }

    public function down(): void
    {
        Schema::table('reward_claims', function (Blueprint $table): void {
            $table->dropColumn([
                'base_prize_amount',
                'adjustment_amount',
                'tenant_price_rule_id',
                'price_rule_snapshot_json',
            ]);
        });

        Schema::table('winning_tickets', function (Blueprint $table): void {
            $table->dropColumn([
                'base_amount',
                'adjustment_amount',
                'tenant_price_rule_id',
                'price_rule_snapshot_json',
            ]);
        });

        Schema::table('tenant_price_rules', function (Blueprint $table): void {
            $table->dropColumn([
                'base_source',
                'adjustment_amount',
                'adjustment_bps',
            ]);
        });
    }
};
