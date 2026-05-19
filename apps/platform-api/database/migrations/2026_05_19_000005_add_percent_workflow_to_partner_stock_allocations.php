<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::table('partner_stock_allocations', function (Blueprint $table): void {
            $table->unsignedInteger('allocation_percent_basis_points')->nullable();
            $table->unsignedInteger('recalled_count')->default(0);
            $table->string('payload_hash', 64)->nullable();
            $table->index(['created_by_admin_id', 'idempotency_key', 'payload_hash'], 'allocations_actor_idem_payload_index');
            $table->index(['game_id', 'partner_id', 'status'], 'allocations_game_partner_status_index');
        });
    }

    public function down(): void
    {
        Schema::table('partner_stock_allocations', function (Blueprint $table): void {
            $table->dropIndex('allocations_actor_idem_payload_index');
            $table->dropIndex('allocations_game_partner_status_index');
            $table->dropColumn([
                'allocation_percent_basis_points',
                'recalled_count',
                'payload_hash',
            ]);
        });
    }
};
