<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::create('customer_notifications', function (Blueprint $table): void {
            $table->string('id', 30)->primary();
            $table->string('tenant_id', 30);
            $table->string('event_key', 100);
            $table->string('category', 40);
            $table->json('title_json');
            $table->json('body_json');
            $table->string('icon_key', 40)->default('notification');
            $table->string('action_key', 50)->default('none');
            $table->string('action_entity_id', 100)->nullable();
            $table->string('subject_type', 60)->nullable();
            $table->string('subject_id', 100)->nullable();
            $table->string('creator_type', 30)->default('system');
            $table->string('creator_id', 30)->nullable();
            $table->string('dedupe_key', 64);
            $table->json('metadata_json')->nullable();
            $table->timestampTz('published_at');
            $table->timestampsTz();

            $table->foreign('tenant_id')->references('id')->on('partner_tenants')->cascadeOnDelete();
            $table->unique(['tenant_id', 'dedupe_key'], 'customer_notifications_tenant_dedupe_unique');
            $table->index(['tenant_id', 'category', 'published_at'], 'customer_notifications_tenant_category_idx');
            $table->index(['tenant_id', 'subject_type', 'subject_id'], 'customer_notifications_tenant_subject_idx');
        });

        Schema::create('customer_notification_recipients', function (Blueprint $table): void {
            $table->string('id', 30)->primary();
            $table->string('tenant_id', 30);
            $table->string('notification_id', 30);
            $table->string('customer_id', 30);
            $table->timestampTz('read_at')->nullable();
            $table->timestampsTz();

            $table->foreign('tenant_id')->references('id')->on('partner_tenants')->cascadeOnDelete();
            $table->foreign('notification_id')->references('id')->on('customer_notifications')->cascadeOnDelete();
            $table->foreign('customer_id')->references('id')->on('customers')->cascadeOnDelete();
            $table->unique(['notification_id', 'customer_id'], 'customer_notification_recipient_unique');
            $table->index(['tenant_id', 'customer_id', 'read_at', 'created_at'], 'customer_notification_unread_idx');
        });

        Schema::create('customer_push_devices', function (Blueprint $table): void {
            $table->string('id', 30)->primary();
            $table->string('tenant_id', 30);
            $table->string('customer_id', 30);
            $table->string('installation_id', 128);
            $table->string('platform', 20);
            $table->text('fcm_token_encrypted');
            $table->string('token_hash', 64);
            $table->string('locale', 20)->nullable();
            $table->string('app_version', 40)->nullable();
            $table->string('device_name')->nullable();
            $table->json('metadata_json')->nullable();
            $table->timestampTz('last_seen_at');
            $table->timestampTz('revoked_at')->nullable();
            $table->timestampsTz();

            $table->foreign('tenant_id')->references('id')->on('partner_tenants')->cascadeOnDelete();
            $table->foreign('customer_id')->references('id')->on('customers')->cascadeOnDelete();
            $table->unique(['tenant_id', 'customer_id', 'installation_id'], 'customer_push_installation_unique');
            $table->index(['tenant_id', 'customer_id', 'revoked_at'], 'customer_push_active_idx');
            $table->index(['tenant_id', 'token_hash'], 'customer_push_token_idx');
        });

        Schema::create('customer_notification_deliveries', function (Blueprint $table): void {
            $table->string('id', 30)->primary();
            $table->string('tenant_id', 30);
            $table->string('recipient_id', 30);
            $table->string('device_id', 30);
            $table->string('status', 30)->default('queued');
            $table->unsignedSmallInteger('attempts')->default(0);
            $table->string('provider_message_id')->nullable();
            $table->string('last_error_code', 80)->nullable();
            $table->timestampTz('next_retry_at')->nullable();
            $table->timestampTz('sent_at')->nullable();
            $table->timestampTz('failed_at')->nullable();
            $table->timestampsTz();

            $table->foreign('tenant_id')->references('id')->on('partner_tenants')->cascadeOnDelete();
            $table->foreign('recipient_id')->references('id')->on('customer_notification_recipients')->cascadeOnDelete();
            $table->foreign('device_id')->references('id')->on('customer_push_devices')->cascadeOnDelete();
            $table->unique(['recipient_id', 'device_id'], 'customer_notification_delivery_unique');
            $table->index(['tenant_id', 'status', 'next_retry_at'], 'customer_notification_delivery_queue_idx');
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('customer_notification_deliveries');
        Schema::dropIfExists('customer_push_devices');
        Schema::dropIfExists('customer_notification_recipients');
        Schema::dropIfExists('customer_notifications');
    }
};
