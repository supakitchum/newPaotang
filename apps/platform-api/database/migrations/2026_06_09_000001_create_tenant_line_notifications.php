<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::create('tenant_line_channels', function (Blueprint $table): void {
            $table->string('id', 30)->primary();
            $table->string('tenant_id', 30);
            $table->string('status')->default('inactive');
            $table->text('messaging_access_token_encrypted')->nullable();
            $table->text('messaging_channel_secret_encrypted')->nullable();
            $table->text('login_channel_id_encrypted')->nullable();
            $table->text('login_channel_secret_encrypted')->nullable();
            $table->string('liff_id', 80)->nullable();
            $table->string('bot_user_id')->nullable();
            $table->string('bot_basic_id')->nullable();
            $table->string('bot_premium_id')->nullable();
            $table->string('bot_display_name')->nullable();
            $table->text('bot_picture_url')->nullable();
            $table->string('chat_mode')->nullable();
            $table->string('mark_as_read_mode')->nullable();
            $table->timestampTz('verified_at')->nullable();
            $table->timestampTz('last_tested_at')->nullable();
            $table->string('last_test_status')->nullable();
            $table->text('last_test_message')->nullable();
            $table->json('metadata_json')->nullable();
            $table->timestampsTz();

            $table->foreign('tenant_id')->references('id')->on('partner_tenants')->cascadeOnDelete();
            $table->unique('tenant_id');
            $table->index(['tenant_id', 'status']);
        });

        Schema::create('customer_line_identities', function (Blueprint $table): void {
            $table->string('id', 30)->primary();
            $table->string('tenant_id', 30);
            $table->string('customer_id', 30);
            $table->string('line_user_id');
            $table->string('display_name')->nullable();
            $table->text('picture_url')->nullable();
            $table->boolean('friend_flag')->default(false);
            $table->boolean('notification_enabled')->default(true);
            $table->timestampTz('linked_at')->nullable();
            $table->timestampTz('last_login_at')->nullable();
            $table->timestampTz('last_friend_checked_at')->nullable();
            $table->timestampTz('unreachable_at')->nullable();
            $table->json('metadata_json')->nullable();
            $table->timestampsTz();

            $table->foreign('tenant_id')->references('id')->on('partner_tenants')->cascadeOnDelete();
            $table->foreign('customer_id')->references('id')->on('customers')->cascadeOnDelete();
            $table->unique(['tenant_id', 'customer_id']);
            $table->unique(['tenant_id', 'line_user_id']);
            $table->index(['tenant_id', 'notification_enabled']);
        });

        Schema::create('customer_line_link_tokens', function (Blueprint $table): void {
            $table->string('id', 30)->primary();
            $table->string('tenant_id', 30);
            $table->string('token_hash', 64);
            $table->string('line_user_id');
            $table->string('display_name')->nullable();
            $table->text('picture_url')->nullable();
            $table->boolean('friend_flag')->default(false);
            $table->string('status')->default('pending');
            $table->timestampTz('expires_at');
            $table->timestampTz('consumed_at')->nullable();
            $table->json('metadata_json')->nullable();
            $table->timestampsTz();

            $table->foreign('tenant_id')->references('id')->on('partner_tenants')->cascadeOnDelete();
            $table->unique(['tenant_id', 'token_hash']);
            $table->index(['tenant_id', 'line_user_id', 'status']);
            $table->index(['tenant_id', 'expires_at']);
        });

        Schema::create('tenant_line_message_templates', function (Blueprint $table): void {
            $table->string('id', 30)->primary();
            $table->string('tenant_id', 30);
            $table->string('event_key');
            $table->boolean('enabled')->default(true);
            $table->string('message_type')->default('flex');
            $table->string('title');
            $table->text('body_text')->nullable();
            $table->json('flex_json')->nullable();
            $table->json('variables_json')->nullable();
            $table->json('metadata_json')->nullable();
            $table->timestampsTz();

            $table->foreign('tenant_id')->references('id')->on('partner_tenants')->cascadeOnDelete();
            $table->unique(['tenant_id', 'event_key']);
            $table->index(['tenant_id', 'enabled']);
        });

        Schema::create('line_notification_deliveries', function (Blueprint $table): void {
            $table->string('id', 30)->primary();
            $table->string('tenant_id', 30);
            $table->string('customer_id', 30)->nullable();
            $table->string('line_user_id')->nullable();
            $table->string('event_key');
            $table->string('source_type');
            $table->string('source_id', 64);
            $table->string('status')->default('queued');
            $table->unsignedSmallInteger('attempts')->default(0);
            $table->timestampTz('next_retry_at')->nullable();
            $table->timestampTz('sent_at')->nullable();
            $table->text('last_error')->nullable();
            $table->json('message_json')->nullable();
            $table->json('line_response_json')->nullable();
            $table->json('metadata_json')->nullable();
            $table->timestampsTz();

            $table->foreign('tenant_id')->references('id')->on('partner_tenants')->cascadeOnDelete();
            $table->foreign('customer_id')->references('id')->on('customers')->nullOnDelete();
            $table->unique(['tenant_id', 'customer_id', 'event_key', 'source_type', 'source_id'], 'line_delivery_unique_source');
            $table->index(['tenant_id', 'status', 'created_at']);
            $table->index(['tenant_id', 'event_key', 'created_at']);
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('line_notification_deliveries');
        Schema::dropIfExists('tenant_line_message_templates');
        Schema::dropIfExists('customer_line_link_tokens');
        Schema::dropIfExists('customer_line_identities');
        Schema::dropIfExists('tenant_line_channels');
    }
};
