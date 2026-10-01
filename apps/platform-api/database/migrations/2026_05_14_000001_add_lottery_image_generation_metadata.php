<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::table('stock_items', function (Blueprint $table): void {
            if (! Schema::hasColumn('stock_items', 'image_url')) {
                $table->string('image_url')->nullable();
            }
            if (! Schema::hasColumn('stock_items', 'image_thumb_url')) {
                $table->string('image_thumb_url')->nullable();
            }
            if (! Schema::hasColumn('stock_items', 'image_storage_path')) {
                $table->string('image_storage_path')->nullable();
            }
            if (! Schema::hasColumn('stock_items', 'image_thumb_storage_path')) {
                $table->string('image_thumb_storage_path')->nullable();
            }
            if (! Schema::hasColumn('stock_items', 'image_generation_status')) {
                $table->string('image_generation_status')->nullable()->index();
            }
            if (! Schema::hasColumn('stock_items', 'image_generation_error')) {
                $table->text('image_generation_error')->nullable();
            }
            if (! Schema::hasColumn('stock_items', 'image_generated_at')) {
                $table->timestampTz('image_generated_at')->nullable();
            }
            if (! Schema::hasColumn('stock_items', 'background_set_type')) {
                $table->string('background_set_type')->nullable();
            }
            if (! Schema::hasColumn('stock_items', 'background_asset_version')) {
                $table->string('background_asset_version')->nullable();
            }
            if (! Schema::hasColumn('stock_items', 'background_asset_index')) {
                $table->unsignedInteger('background_asset_index')->nullable();
            }
        });

        Schema::table('local_stock_items', function (Blueprint $table): void {
            if (! Schema::hasColumn('local_stock_items', 'image_storage_path')) {
                $table->string('image_storage_path')->nullable();
            }
            if (! Schema::hasColumn('local_stock_items', 'image_thumb_storage_path')) {
                $table->string('image_thumb_storage_path')->nullable();
            }
            if (! Schema::hasColumn('local_stock_items', 'image_generation_status')) {
                $table->string('image_generation_status')->nullable()->index();
            }
            if (! Schema::hasColumn('local_stock_items', 'image_generation_error')) {
                $table->text('image_generation_error')->nullable();
            }
            if (! Schema::hasColumn('local_stock_items', 'image_generated_at')) {
                $table->timestampTz('image_generated_at')->nullable();
            }
        });

        Schema::create('partner_lottery_branding_asset_sets', function (Blueprint $table): void {
            $table->string('id', 30)->primary();
            $table->string('partner_id', 30);
            $table->string('version', 64)->default('v1');
            $table->string('status')->default('ready');
            $table->string('logo_qr_asset_id', 30);
            $table->string('right_sidebar_asset_id', 30);
            $table->string('logo_bottom_asset_id', 30);
            $table->string('logo_qr_storage_path')->nullable();
            $table->string('right_sidebar_storage_path')->nullable();
            $table->string('logo_bottom_storage_path')->nullable();
            $table->string('uploaded_by_admin_id', 30)->nullable();
            $table->timestampTz('activated_at')->nullable();
            $table->timestampTz('locked_at')->nullable();
            $table->timestampsTz();

            $table->foreign('partner_id')->references('id')->on('partners')->cascadeOnDelete();
            $table->foreign('logo_qr_asset_id')->references('id')->on('platform_assets')->restrictOnDelete();
            $table->foreign('right_sidebar_asset_id')->references('id')->on('platform_assets')->restrictOnDelete();
            $table->foreign('logo_bottom_asset_id')->references('id')->on('platform_assets')->restrictOnDelete();
            $table->foreign('uploaded_by_admin_id')->references('id')->on('admin_users')->nullOnDelete();
            $table->unique(['partner_id', 'version']);
            $table->index(['partner_id', 'status']);
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('partner_lottery_branding_asset_sets');

        Schema::table('local_stock_items', function (Blueprint $table): void {
            foreach ([
                'image_storage_path',
                'image_thumb_storage_path',
                'image_generation_status',
                'image_generation_error',
                'image_generated_at',
            ] as $column) {
                if (Schema::hasColumn('local_stock_items', $column)) {
                    $table->dropColumn($column);
                }
            }
        });

        Schema::table('stock_items', function (Blueprint $table): void {
            foreach ([
                'image_url',
                'image_thumb_url',
                'image_storage_path',
                'image_thumb_storage_path',
                'image_generation_status',
                'image_generation_error',
                'image_generated_at',
                'background_set_type',
                'background_asset_version',
                'background_asset_index',
            ] as $column) {
                if (Schema::hasColumn('stock_items', $column)) {
                    $table->dropColumn($column);
                }
            }
        });
    }
};
