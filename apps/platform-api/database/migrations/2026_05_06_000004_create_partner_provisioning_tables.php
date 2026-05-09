<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::create('partner_tenant_settings', function (Blueprint $table): void {
            $table->string('id', 30)->primary();
            $table->string('tenant_id', 30)->unique();
            $table->string('site_name');
            $table->string('display_name')->nullable();
            $table->string('locale')->default('th-TH');
            $table->string('timezone')->default('Asia/Bangkok');
            $table->string('support_email')->nullable();
            $table->string('support_phone')->nullable();
            $table->string('default_title')->nullable();
            $table->string('title_template')->nullable();
            $table->text('default_description')->nullable();
            $table->json('default_keywords_json')->nullable();
            $table->string('robots_default')->default('index,follow');
            $table->boolean('sitemap_enabled')->default(true);
            $table->boolean('robots_enabled')->default(true);
            $table->boolean('maintenance_active')->default(false);
            $table->string('maintenance_mode')->nullable();
            $table->text('maintenance_message')->nullable();
            $table->timestampTz('maintenance_expected_end_at')->nullable();
            $table->unsignedInteger('maintenance_retry_after_seconds')->nullable();
            $table->json('maintenance_allowed_routes_json')->nullable();
            $table->json('maintenance_blocked_route_patterns_json')->nullable();
            $table->string('api_base_url')->nullable();
            $table->string('realtime_url')->nullable();
            $table->string('asset_cdn_base_url')->nullable();
            $table->unsignedInteger('config_version')->default(1);
            $table->timestampsTz();

            $table->foreign('tenant_id')->references('id')->on('partner_tenants')->cascadeOnDelete();
        });

        Schema::create('partner_tenant_themes', function (Blueprint $table): void {
            $table->string('id', 30)->primary();
            $table->string('tenant_id', 30)->unique();
            $table->string('logo_url')->nullable();
            $table->string('favicon_url')->nullable();
            $table->string('og_image_url')->nullable();
            $table->string('primary_color')->default('#0F766E');
            $table->string('secondary_color')->default('#2563EB');
            $table->string('accent_color')->default('#F59E0B');
            $table->string('background_color')->default('#FFFFFF');
            $table->string('text_color')->default('#111827');
            $table->string('font_family')->default('Inter, sans-serif');
            $table->unsignedInteger('config_version')->default(1);
            $table->timestampsTz();

            $table->foreign('tenant_id')->references('id')->on('partner_tenants')->cascadeOnDelete();
        });

        Schema::create('partner_tenant_feature_flags', function (Blueprint $table): void {
            $table->string('id', 30)->primary();
            $table->string('tenant_id', 30);
            $table->string('feature_key');
            $table->boolean('enabled')->default(false);
            $table->timestampsTz();

            $table->foreign('tenant_id')->references('id')->on('partner_tenants')->cascadeOnDelete();
            $table->unique(['tenant_id', 'feature_key']);
        });

        Schema::create('partner_tenant_deployment_profiles', function (Blueprint $table): void {
            $table->string('id', 30)->primary();
            $table->string('tenant_id', 30)->unique();
            $table->string('mode')->default('shared');
            $table->string('status')->default('active');
            $table->string('runtime_region')->nullable();
            $table->string('resource_pool')->nullable();
            $table->timestampsTz();

            $table->foreign('tenant_id')->references('id')->on('partner_tenants')->cascadeOnDelete();
        });

        Schema::create('partner_monitoring_profiles', function (Blueprint $table): void {
            $table->string('id', 30)->primary();
            $table->string('partner_id', 30)->unique();
            $table->string('status')->default('active');
            $table->string('health_status')->default('unknown');
            $table->timestampsTz();

            $table->foreign('partner_id')->references('id')->on('partners')->cascadeOnDelete();
        });

        Schema::create('partner_usage_meters', function (Blueprint $table): void {
            $table->string('id', 30)->primary();
            $table->string('partner_id', 30);
            $table->string('meter_key');
            $table->unsignedBigInteger('value')->default(0);
            $table->unsignedBigInteger('limit_value')->nullable();
            $table->string('status')->default('active');
            $table->timestampsTz();

            $table->foreign('partner_id')->references('id')->on('partners')->cascadeOnDelete();
            $table->unique(['partner_id', 'meter_key']);
        });

        Schema::create('partner_alert_policies', function (Blueprint $table): void {
            $table->string('id', 30)->primary();
            $table->string('partner_id', 30);
            $table->string('policy_key');
            $table->string('status')->default('active');
            $table->string('severity')->default('warning');
            $table->json('config_json')->nullable();
            $table->timestampsTz();

            $table->foreign('partner_id')->references('id')->on('partners')->cascadeOnDelete();
            $table->unique(['partner_id', 'policy_key']);
        });

        Schema::create('partner_health_checks', function (Blueprint $table): void {
            $table->string('id', 30)->primary();
            $table->string('partner_id', 30);
            $table->string('tenant_id', 30)->nullable();
            $table->string('check_key');
            $table->string('health_status')->default('unknown');
            $table->timestampTz('checked_at')->nullable();
            $table->timestampsTz();

            $table->foreign('partner_id')->references('id')->on('partners')->cascadeOnDelete();
            $table->foreign('tenant_id')->references('id')->on('partner_tenants')->nullOnDelete();
            $table->unique(['partner_id', 'check_key']);
            $table->index(['tenant_id', 'health_status']);
        });

        Schema::create('partner_billing_plan_bindings', function (Blueprint $table): void {
            $table->string('id', 30)->primary();
            $table->string('partner_id', 30)->unique();
            $table->string('billing_plan_code')->default('starter');
            $table->string('status')->default('trial');
            $table->timestampTz('effective_at')->nullable();
            $table->timestampsTz();

            $table->foreign('partner_id')->references('id')->on('partners')->cascadeOnDelete();
        });

        Schema::create('partner_api_clients', function (Blueprint $table): void {
            $table->string('id', 30)->primary();
            $table->string('partner_id', 30);
            $table->string('name');
            $table->string('client_key')->unique();
            $table->string('secret_hash', 64);
            $table->string('status')->default('active');
            $table->json('scopes_json')->nullable();
            $table->timestampTz('last_used_at')->nullable();
            $table->timestampTz('revoked_at')->nullable();
            $table->timestampsTz();

            $table->foreign('partner_id')->references('id')->on('partners')->cascadeOnDelete();
            $table->index(['partner_id', 'status']);
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('partner_api_clients');
        Schema::dropIfExists('partner_billing_plan_bindings');
        Schema::dropIfExists('partner_health_checks');
        Schema::dropIfExists('partner_alert_policies');
        Schema::dropIfExists('partner_usage_meters');
        Schema::dropIfExists('partner_monitoring_profiles');
        Schema::dropIfExists('partner_tenant_deployment_profiles');
        Schema::dropIfExists('partner_tenant_feature_flags');
        Schema::dropIfExists('partner_tenant_themes');
        Schema::dropIfExists('partner_tenant_settings');
    }
};
