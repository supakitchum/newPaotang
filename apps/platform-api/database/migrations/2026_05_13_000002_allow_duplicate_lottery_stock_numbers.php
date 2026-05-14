<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Support\Facades\DB;

return new class extends Migration
{
    public function up(): void
    {
        DB::statement('ALTER TABLE stock_generation_batches DROP CONSTRAINT IF EXISTS stock_generation_batches_game_id_type_payload_hash_unique');
        DB::statement('DROP INDEX IF EXISTS stock_generation_batches_game_id_type_payload_hash_unique');
        DB::statement('CREATE INDEX IF NOT EXISTS stock_generation_batches_game_id_type_payload_hash_index ON stock_generation_batches (game_id, type, payload_hash)');

        DB::statement('ALTER TABLE stock_items DROP CONSTRAINT IF EXISTS stock_items_game_id_full_number_unique');
        DB::statement('DROP INDEX IF EXISTS stock_items_game_id_full_number_unique');
        DB::statement('CREATE INDEX IF NOT EXISTS stock_items_game_id_full_number_index ON stock_items (game_id, full_number)');

        DB::statement('ALTER TABLE local_stock_items DROP CONSTRAINT IF EXISTS local_stock_items_tenant_id_game_id_store_id_full_number_unique');
        DB::statement('DROP INDEX IF EXISTS local_stock_items_tenant_id_game_id_store_id_full_number_unique');
    }

    public function down(): void
    {
        DB::statement('DROP INDEX IF EXISTS stock_generation_batches_game_id_type_payload_hash_index');
        DB::statement('DROP INDEX IF EXISTS stock_items_game_id_full_number_index');
    }
};
