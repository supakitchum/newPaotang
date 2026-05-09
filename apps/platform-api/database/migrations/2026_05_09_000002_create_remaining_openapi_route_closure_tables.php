<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::create('platform_assets', function (Blueprint $table): void {
            $table->string('id', 30)->primary();
            $table->string('scope_type', 20);
            $table->string('tenant_id', 30)->nullable();
            $table->string('created_by_admin_id', 30)->nullable();
            $table->string('purpose');
            $table->string('file_name');
            $table->string('content_type');
            $table->unsignedBigInteger('size_bytes');
            $table->string('checksum_sha256')->nullable();
            $table->string('status')->default('pending_upload');
            $table->string('storage_key')->nullable();
            $table->string('upload_url')->nullable();
            $table->string('public_url')->nullable();
            $table->json('metadata_json')->nullable();
            $table->timestampTz('expires_at')->nullable();
            $table->timestampTz('committed_at')->nullable();
            $table->timestampsTz();

            $table->foreign('tenant_id')->references('id')->on('partner_tenants')->cascadeOnDelete();
            $table->foreign('created_by_admin_id')->references('id')->on('admin_users')->nullOnDelete();
            $table->index(['scope_type', 'tenant_id', 'status']);
            $table->index(['tenant_id', 'purpose']);
        });

        Schema::create('tenant_payment_settings', function (Blueprint $table): void {
            $table->string('id', 30)->primary();
            $table->string('tenant_id', 30)->unique();
            $table->string('status')->default('active');
            $table->string('provider_mode')->default('manual_only');
            $table->string('default_currency', 3)->default('THB');
            $table->boolean('allow_manual_topup')->default(true);
            $table->boolean('allow_external_payment')->default(false);
            $table->string('payment_provider_status')->default('blocked_external');
            $table->json('config_json')->nullable();
            $table->json('secret_status_json')->nullable();
            $table->timestampsTz();

            $table->foreign('tenant_id')->references('id')->on('partner_tenants')->cascadeOnDelete();
            $table->index(['tenant_id', 'status']);
        });

        Schema::create('tenant_payment_channels', function (Blueprint $table): void {
            $table->string('id', 30)->primary();
            $table->string('tenant_id', 30);
            $table->string('code');
            $table->string('name');
            $table->string('provider')->default('manual');
            $table->string('channel_type')->default('manual');
            $table->string('status')->default('draft');
            $table->unsignedInteger('sort_order')->default(0);
            $table->json('config_json')->nullable();
            $table->json('secret_status_json')->nullable();
            $table->timestampsTz();

            $table->foreign('tenant_id')->references('id')->on('partner_tenants')->cascadeOnDelete();
            $table->unique(['tenant_id', 'code']);
            $table->index(['tenant_id', 'status']);
            $table->index(['tenant_id', 'provider']);
        });

        Schema::create('partner_tenant_seo_settings', function (Blueprint $table): void {
            $table->string('id', 30)->primary();
            $table->string('tenant_id', 30)->unique();
            $table->string('status')->default('active');
            $table->string('default_title')->nullable();
            $table->string('title_template')->nullable();
            $table->text('default_description')->nullable();
            $table->json('default_keywords_json')->nullable();
            $table->string('robots_default')->default('index,follow');
            $table->string('canonical_base_url')->nullable();
            $table->string('og_image_url')->nullable();
            $table->unsignedInteger('config_version')->default(1);
            $table->timestampsTz();

            $table->foreign('tenant_id')->references('id')->on('partner_tenants')->cascadeOnDelete();
            $table->index(['tenant_id', 'status']);
        });

        Schema::create('partner_tenant_seo_pages', function (Blueprint $table): void {
            $table->string('id', 30)->primary();
            $table->string('tenant_id', 30);
            $table->string('path');
            $table->string('title');
            $table->text('description')->nullable();
            $table->string('canonical_url')->nullable();
            $table->string('robots')->default('index,follow');
            $table->string('og_image_url')->nullable();
            $table->string('status')->default('active');
            $table->json('metadata_json')->nullable();
            $table->timestampsTz();

            $table->foreign('tenant_id')->references('id')->on('partner_tenants')->cascadeOnDelete();
            $table->unique(['tenant_id', 'path']);
            $table->index(['tenant_id', 'status']);
        });

        Schema::create('partner_tenant_redirects', function (Blueprint $table): void {
            $table->string('id', 30)->primary();
            $table->string('tenant_id', 30);
            $table->string('source_path');
            $table->string('target_url');
            $table->unsignedSmallInteger('status_code')->default(301);
            $table->string('status')->default('active');
            $table->json('metadata_json')->nullable();
            $table->timestampsTz();

            $table->foreign('tenant_id')->references('id')->on('partner_tenants')->cascadeOnDelete();
            $table->unique(['tenant_id', 'source_path']);
            $table->index(['tenant_id', 'status']);
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('partner_tenant_redirects');
        Schema::dropIfExists('partner_tenant_seo_pages');
        Schema::dropIfExists('partner_tenant_seo_settings');
        Schema::dropIfExists('tenant_payment_channels');
        Schema::dropIfExists('tenant_payment_settings');
        Schema::dropIfExists('platform_assets');
    }
};
