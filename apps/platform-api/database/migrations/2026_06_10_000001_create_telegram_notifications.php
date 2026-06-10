<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::create('telegram_bot_connections', function (Blueprint $table): void {
            $table->string('id', 30)->primary();
            $table->string('status')->default('inactive');
            $table->text('bot_token_encrypted')->nullable();
            $table->string('bot_id')->nullable();
            $table->string('bot_username')->nullable();
            $table->string('bot_first_name')->nullable();
            $table->bigInteger('last_update_id')->nullable();
            $table->timestampTz('verified_at')->nullable();
            $table->timestampTz('last_synced_at')->nullable();
            $table->string('last_test_status')->nullable();
            $table->text('last_test_message')->nullable();
            $table->json('metadata_json')->nullable();
            $table->timestampsTz();

            $table->index(['status']);
        });

        Schema::create('telegram_chats', function (Blueprint $table): void {
            $table->string('id', 30)->primary();
            $table->string('chat_id', 64);
            $table->string('chat_type')->nullable();
            $table->string('title')->nullable();
            $table->string('username')->nullable();
            $table->string('first_name')->nullable();
            $table->string('last_name')->nullable();
            $table->timestampTz('last_seen_at')->nullable();
            $table->json('metadata_json')->nullable();
            $table->timestampsTz();

            $table->unique('chat_id');
            $table->index(['chat_type', 'last_seen_at']);
        });

        Schema::create('tenant_telegram_notification_routes', function (Blueprint $table): void {
            $table->string('id', 30)->primary();
            $table->string('tenant_id', 30);
            $table->string('event_key');
            $table->string('chat_id', 64)->nullable();
            $table->boolean('enabled')->default(false);
            $table->json('metadata_json')->nullable();
            $table->timestampsTz();

            $table->foreign('tenant_id')->references('id')->on('partner_tenants')->cascadeOnDelete();
            $table->foreign('chat_id')->references('chat_id')->on('telegram_chats')->nullOnDelete();
            $table->unique(['tenant_id', 'event_key']);
            $table->index(['tenant_id', 'enabled']);
            $table->index(['event_key', 'enabled']);
        });

        Schema::create('telegram_message_templates', function (Blueprint $table): void {
            $table->string('id', 30)->primary();
            $table->string('event_key');
            $table->boolean('enabled')->default(true);
            $table->string('title');
            $table->text('body_text');
            $table->json('variables_json')->nullable();
            $table->json('metadata_json')->nullable();
            $table->timestampsTz();

            $table->unique('event_key');
            $table->index(['enabled']);
        });

        Schema::create('telegram_notification_deliveries', function (Blueprint $table): void {
            $table->string('id', 30)->primary();
            $table->string('tenant_id', 30);
            $table->string('event_key');
            $table->string('chat_id', 64)->nullable();
            $table->string('source_type');
            $table->string('source_id', 64);
            $table->string('status')->default('queued');
            $table->unsignedSmallInteger('attempts')->default(0);
            $table->timestampTz('next_retry_at')->nullable();
            $table->timestampTz('sent_at')->nullable();
            $table->text('last_error')->nullable();
            $table->text('message_text')->nullable();
            $table->json('telegram_response_json')->nullable();
            $table->json('metadata_json')->nullable();
            $table->timestampsTz();

            $table->foreign('tenant_id')->references('id')->on('partner_tenants')->cascadeOnDelete();
            $table->foreign('chat_id')->references('chat_id')->on('telegram_chats')->nullOnDelete();
            $table->unique(['tenant_id', 'event_key', 'source_type', 'source_id'], 'telegram_delivery_unique_source');
            $table->index(['tenant_id', 'status', 'created_at']);
            $table->index(['event_key', 'created_at']);
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('telegram_notification_deliveries');
        Schema::dropIfExists('telegram_message_templates');
        Schema::dropIfExists('tenant_telegram_notification_routes');
        Schema::dropIfExists('telegram_chats');
        Schema::dropIfExists('telegram_bot_connections');
    }
};
