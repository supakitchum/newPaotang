<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::create('tenant_announcements', function (Blueprint $table): void {
            $table->string('id', 30)->primary();
            $table->string('tenant_id', 30);
            $table->string('title');
            $table->string('slug');
            $table->text('summary')->nullable();
            $table->longText('body')->nullable();
            $table->string('status')->default('draft');
            $table->boolean('modal_enabled')->default(true);
            $table->boolean('important')->default(false);
            $table->timestampTz('display_start_at')->nullable();
            $table->timestampTz('display_end_at')->nullable();
            $table->integer('sort_order')->default(0);
            $table->string('image_full_asset_id', 30)->nullable();
            $table->string('image_thumb_asset_id', 30)->nullable();
            $table->json('metadata_json')->nullable();
            $table->timestampsTz();

            $table->foreign('tenant_id')->references('id')->on('partner_tenants')->cascadeOnDelete();
            $table->foreign('image_full_asset_id')->references('id')->on('platform_assets')->nullOnDelete();
            $table->foreign('image_thumb_asset_id')->references('id')->on('platform_assets')->nullOnDelete();
            $table->unique(['tenant_id', 'slug']);
            $table->index(['tenant_id', 'status', 'display_start_at', 'display_end_at']);
            $table->index(['tenant_id', 'modal_enabled', 'important', 'sort_order']);
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('tenant_announcements');
    }
};
