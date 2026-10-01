<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::table('lottery_image_background_asset_sets', function (Blueprint $table): void {
            $table->unsignedInteger('position')->default(1)->after('set_type');
            $table->dropUnique(['game_id', 'version', 'set_type']);
            $table->unique(['game_id', 'version', 'set_type', 'position'], 'lottery_image_background_sets_scope_position_unique');
        });
    }

    public function down(): void
    {
        Schema::table('lottery_image_background_asset_sets', function (Blueprint $table): void {
            $table->dropUnique('lottery_image_background_sets_scope_position_unique');
            $table->unique(['game_id', 'version', 'set_type']);
            $table->dropColumn('position');
        });
    }
};
