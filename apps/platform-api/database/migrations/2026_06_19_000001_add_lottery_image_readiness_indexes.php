<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Support\Facades\DB;

return new class extends Migration
{
    public function up(): void
    {
        DB::statement('CREATE INDEX IF NOT EXISTS stock_items_image_readiness_idx ON stock_items (game_id, image_generation_status, background_asset_version, background_set_type, batch_id)');
        DB::statement('CREATE INDEX IF NOT EXISTS stock_items_image_error_readiness_idx ON stock_items (game_id, updated_at DESC, background_asset_version, background_set_type, batch_id) WHERE image_generation_error IS NOT NULL');
        DB::statement('CREATE INDEX IF NOT EXISTS local_stock_items_image_readiness_idx ON local_stock_items (game_id, image_generation_status, stock_item_id)');
        DB::statement('CREATE INDEX IF NOT EXISTS local_stock_items_image_error_readiness_idx ON local_stock_items (game_id, updated_at DESC, stock_item_id) WHERE image_generation_error IS NOT NULL');
        DB::statement('CREATE INDEX IF NOT EXISTS lottery_background_sets_readiness_idx ON lottery_image_background_asset_sets (game_id, version, set_type, status, position)');
    }

    public function down(): void
    {
        DB::statement('DROP INDEX IF EXISTS lottery_background_sets_readiness_idx');
        DB::statement('DROP INDEX IF EXISTS local_stock_items_image_error_readiness_idx');
        DB::statement('DROP INDEX IF EXISTS local_stock_items_image_readiness_idx');
        DB::statement('DROP INDEX IF EXISTS stock_items_image_error_readiness_idx');
        DB::statement('DROP INDEX IF EXISTS stock_items_image_readiness_idx');
    }
};
