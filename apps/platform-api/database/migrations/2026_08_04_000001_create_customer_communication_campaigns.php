<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::create('customer_communication_campaigns', function (Blueprint $table): void {
            $table->string('id', 30)->primary();
            $table->string('tenant_id', 30);
            $table->string('name', 160);
            $table->string('audience_type', 30)->default('all_customers');
            $table->string('customer_id', 30)->nullable();
            $table->string('status', 30)->default('draft');
            $table->json('title_json');
            $table->json('body_json');
            $table->string('action_key', 50)->default('none');
            $table->string('action_entity_id', 100)->nullable();
            $table->string('image_full_asset_id', 30)->nullable();
            $table->string('image_thumb_asset_id', 30)->nullable();
            $table->string('notification_id', 30)->nullable();
            $table->string('created_by_admin_id', 30)->nullable();
            $table->string('dedupe_key', 64);
            $table->timestampTz('scheduled_at')->nullable();
            $table->timestampTz('published_at')->nullable();
            $table->timestampTz('cancelled_at')->nullable();
            $table->string('last_error_code', 100)->nullable();
            $table->json('metadata_json')->nullable();
            $table->timestampsTz();

            $table->foreign('tenant_id')->references('id')->on('partner_tenants')->cascadeOnDelete();
            $table->foreign('customer_id')->references('id')->on('customers')->nullOnDelete();
            $table->foreign('image_full_asset_id')->references('id')->on('platform_assets')->nullOnDelete();
            $table->foreign('image_thumb_asset_id')->references('id')->on('platform_assets')->nullOnDelete();
            $table->foreign('notification_id')->references('id')->on('customer_notifications')->nullOnDelete();
            $table->foreign('created_by_admin_id')->references('id')->on('admin_users')->nullOnDelete();
            $table->unique(['tenant_id', 'dedupe_key'], 'customer_communication_campaign_dedupe_unique');
            $table->index(['tenant_id', 'status', 'scheduled_at'], 'customer_communication_campaign_due_idx');
            $table->index(['tenant_id', 'created_at'], 'customer_communication_campaign_history_idx');
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('customer_communication_campaigns');
    }
};
