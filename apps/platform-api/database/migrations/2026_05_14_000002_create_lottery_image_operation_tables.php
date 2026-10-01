<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::create('lottery_image_background_asset_sets', function (Blueprint $table): void {
            $table->string('id', 30)->primary();
            $table->string('game_id', 30);
            $table->string('version', 64);
            $table->string('set_type', 20);
            $table->string('status')->default('ready');
            $table->string('source_asset_id', 30);
            $table->string('full_asset_id', 30);
            $table->string('thumb_asset_id', 30);
            $table->string('source_storage_path')->nullable();
            $table->string('full_storage_path')->nullable();
            $table->string('thumb_storage_path')->nullable();
            $table->string('source_content_type')->nullable();
            $table->string('full_content_type')->nullable();
            $table->string('thumb_content_type')->nullable();
            $table->unsignedInteger('source_width')->nullable();
            $table->unsignedInteger('source_height')->nullable();
            $table->unsignedInteger('full_width')->nullable();
            $table->unsignedInteger('full_height')->nullable();
            $table->unsignedInteger('thumb_width')->nullable();
            $table->unsignedInteger('thumb_height')->nullable();
            $table->unsignedBigInteger('source_size_bytes')->nullable();
            $table->unsignedBigInteger('full_size_bytes')->nullable();
            $table->unsignedBigInteger('thumb_size_bytes')->nullable();
            $table->string('uploaded_by_admin_id', 30)->nullable();
            $table->timestampTz('activated_at')->nullable();
            $table->timestampTz('retired_at')->nullable();
            $table->json('metadata_json')->nullable();
            $table->timestampsTz();

            $table->foreign('game_id')->references('id')->on('games')->cascadeOnDelete();
            $table->foreign('source_asset_id')->references('id')->on('platform_assets')->restrictOnDelete();
            $table->foreign('full_asset_id')->references('id')->on('platform_assets')->restrictOnDelete();
            $table->foreign('thumb_asset_id')->references('id')->on('platform_assets')->restrictOnDelete();
            $table->foreign('uploaded_by_admin_id')->references('id')->on('admin_users')->nullOnDelete();
            $table->unique(['game_id', 'version', 'set_type']);
            $table->index(['game_id', 'status']);
            $table->index(['game_id', 'version', 'status']);
        });

        Schema::create('lottery_image_mix_settings', function (Blueprint $table): void {
            $table->string('id', 30)->primary();
            $table->string('game_id', 30)->unique();
            $table->unsignedTinyInteger('odd_percentage');
            $table->unsignedTinyInteger('even_percentage');
            $table->unsignedTinyInteger('charity_percentage');
            $table->string('updated_by_admin_id', 30)->nullable();
            $table->timestampsTz();

            $table->foreign('game_id')->references('id')->on('games')->cascadeOnDelete();
            $table->foreign('updated_by_admin_id')->references('id')->on('admin_users')->nullOnDelete();
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('lottery_image_mix_settings');
        Schema::dropIfExists('lottery_image_background_asset_sets');
    }
};
