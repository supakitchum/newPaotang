<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::create('support_tenants', function (Blueprint $table): void {
            $table->string('id', 30)->primary();
            $table->string('name');
            $table->string('locale', 16)->default('th-TH');
            $table->boolean('enabled')->default(true);
            $table->timestampsTz();
        });

        Schema::create('support_actors', function (Blueprint $table): void {
            $table->string('id', 30)->primary();
            $table->string('tenant_id', 30);
            $table->string('actor_type', 16);
            $table->string('external_id', 64);
            $table->string('display_name')->nullable();
            $table->string('member_code', 80)->nullable();
            $table->string('status', 24)->default('active');
            $table->jsonb('permissions_json')->nullable();
            $table->timestampTz('last_authenticated_at')->nullable();
            $table->timestampsTz();
            $table->foreign('tenant_id')->references('id')->on('support_tenants')->cascadeOnDelete();
            $table->unique(['tenant_id', 'actor_type', 'external_id']);
            $table->index(['tenant_id', 'actor_type', 'status']);
        });

        Schema::create('support_settings', function (Blueprint $table): void {
            $table->string('tenant_id', 30)->primary();
            $table->boolean('enabled')->default(true);
            $table->unsignedSmallInteger('default_agent_capacity')->default(3);
            $table->unsignedSmallInteger('max_attachments_per_message')->default(4);
            $table->unsignedInteger('max_attachment_bytes')->default(8388608);
            $table->jsonb('content_json')->nullable();
            $table->timestampsTz();
            $table->foreign('tenant_id')->references('id')->on('support_tenants')->cascadeOnDelete();
        });

        Schema::create('support_categories', function (Blueprint $table): void {
            $table->string('id', 30)->primary();
            $table->string('tenant_id', 30);
            $table->string('code', 80);
            $table->jsonb('name_json');
            $table->string('icon_key', 80)->nullable();
            $table->boolean('is_fallback')->default(false);
            $table->string('status', 24)->default('active');
            $table->unsignedInteger('sort_order')->default(0);
            $table->timestampsTz();
            $table->foreign('tenant_id')->references('id')->on('support_tenants')->cascadeOnDelete();
            $table->unique(['tenant_id', 'code']);
            $table->index(['tenant_id', 'status', 'sort_order']);
        });

        Schema::create('support_faqs', function (Blueprint $table): void {
            $table->string('id', 30)->primary();
            $table->string('tenant_id', 30);
            $table->string('category_id', 30)->nullable();
            $table->jsonb('question_json');
            $table->jsonb('answer_json');
            $table->jsonb('keywords_json')->nullable();
            $table->string('status', 24)->default('draft');
            $table->unsignedInteger('sort_order')->default(0);
            $table->timestampTz('published_at')->nullable();
            $table->timestampsTz();
            $table->foreign('tenant_id')->references('id')->on('support_tenants')->cascadeOnDelete();
            $table->foreign('category_id')->references('id')->on('support_categories')->nullOnDelete();
            $table->index(['tenant_id', 'status', 'sort_order']);
            $table->index(['tenant_id', 'category_id', 'status']);
        });

        Schema::create('support_faq_feedback', function (Blueprint $table): void {
            $table->string('id', 30)->primary();
            $table->string('tenant_id', 30);
            $table->string('faq_id', 30);
            $table->string('customer_actor_id', 30);
            $table->boolean('helpful');
            $table->timestampsTz();
            $table->foreign('tenant_id')->references('id')->on('support_tenants')->cascadeOnDelete();
            $table->foreign('faq_id')->references('id')->on('support_faqs')->cascadeOnDelete();
            $table->foreign('customer_actor_id')->references('id')->on('support_actors')->cascadeOnDelete();
            $table->unique(['tenant_id', 'faq_id', 'customer_actor_id']);
            $table->index(['tenant_id', 'faq_id', 'helpful']);
        });

        Schema::create('support_tickets', function (Blueprint $table): void {
            $table->string('id', 30)->primary();
            $table->string('public_no', 32)->unique();
            $table->string('tenant_id', 30);
            $table->string('customer_actor_id', 30);
            $table->string('category_id', 30)->nullable();
            $table->string('subject', 120);
            $table->string('status', 24)->default('queued');
            $table->unsignedSmallInteger('priority')->default(0);
            $table->string('assigned_admin_actor_id', 30)->nullable();
            $table->unsignedSmallInteger('active_slot')->nullable()->default(1);
            $table->string('referenced_ticket_id', 30)->nullable();
            $table->unsignedBigInteger('latest_sequence')->default(0);
            $table->string('last_message_preview', 240)->nullable();
            $table->string('closed_by_type', 16)->nullable();
            $table->string('closed_by_actor_id', 30)->nullable();
            $table->string('close_reason', 500)->nullable();
            $table->timestampTz('queued_at');
            $table->timestampTz('assigned_at')->nullable();
            $table->timestampTz('first_response_at')->nullable();
            $table->timestampTz('waiting_customer_at')->nullable();
            $table->timestampTz('last_message_at')->nullable();
            $table->timestampTz('closed_at')->nullable();
            $table->timestampsTz();
            $table->foreign('tenant_id')->references('id')->on('support_tenants')->cascadeOnDelete();
            $table->foreign('customer_actor_id')->references('id')->on('support_actors')->restrictOnDelete();
            $table->foreign('category_id')->references('id')->on('support_categories')->nullOnDelete();
            $table->foreign('assigned_admin_actor_id')->references('id')->on('support_actors')->nullOnDelete();
            $table->unique(['tenant_id', 'customer_actor_id', 'active_slot']);
            $table->index(['tenant_id', 'status', 'priority', 'queued_at']);
            $table->index(['tenant_id', 'assigned_admin_actor_id', 'status']);
            $table->index(['tenant_id', 'customer_actor_id', 'updated_at']);
        });
        Schema::table('support_tickets', function (Blueprint $table): void {
            $table->foreign('referenced_ticket_id')
                ->references('id')
                ->on('support_tickets')
                ->nullOnDelete();
        });

        Schema::create('support_messages', function (Blueprint $table): void {
            $table->string('id', 40)->primary();
            $table->string('tenant_id', 30);
            $table->string('ticket_id', 30);
            $table->unsignedBigInteger('sequence');
            $table->string('sender_type', 16);
            $table->string('sender_actor_id', 30)->nullable();
            $table->text('body')->nullable();
            $table->string('message_type', 24)->default('text');
            $table->jsonb('metadata_json')->nullable();
            $table->timestampsTz();
            $table->foreign('tenant_id')->references('id')->on('support_tenants')->cascadeOnDelete();
            $table->foreign('ticket_id')->references('id')->on('support_tickets')->cascadeOnDelete();
            $table->foreign('sender_actor_id')->references('id')->on('support_actors')->nullOnDelete();
            $table->unique(['ticket_id', 'sequence']);
            $table->index(['tenant_id', 'ticket_id', 'sequence']);
        });

        Schema::create('support_attachments', function (Blueprint $table): void {
            $table->string('id', 30)->primary();
            $table->string('tenant_id', 30);
            $table->string('ticket_id', 30);
            $table->string('message_id', 40);
            $table->string('disk', 40);
            $table->string('storage_path');
            $table->string('mime_type', 80);
            $table->unsignedBigInteger('byte_size');
            $table->string('checksum_sha256', 64);
            $table->unsignedInteger('width')->nullable();
            $table->unsignedInteger('height')->nullable();
            $table->string('original_name', 255)->nullable();
            $table->timestampsTz();
            $table->foreign('tenant_id')->references('id')->on('support_tenants')->cascadeOnDelete();
            $table->foreign('ticket_id')->references('id')->on('support_tickets')->cascadeOnDelete();
            $table->foreign('message_id')->references('id')->on('support_messages')->cascadeOnDelete();
            $table->index(['tenant_id', 'message_id']);
        });

        Schema::create('support_read_receipts', function (Blueprint $table): void {
            $table->string('ticket_id', 30);
            $table->string('actor_id', 30);
            $table->unsignedBigInteger('last_read_sequence')->default(0);
            $table->timestampTz('read_at')->nullable();
            $table->timestampsTz();
            $table->primary(['ticket_id', 'actor_id']);
            $table->foreign('ticket_id')->references('id')->on('support_tickets')->cascadeOnDelete();
            $table->foreign('actor_id')->references('id')->on('support_actors')->cascadeOnDelete();
        });

        Schema::create('support_ratings', function (Blueprint $table): void {
            $table->string('id', 30)->primary();
            $table->string('tenant_id', 30);
            $table->string('ticket_id', 30)->unique();
            $table->string('customer_actor_id', 30);
            $table->unsignedSmallInteger('stars');
            $table->string('comment', 500)->nullable();
            $table->timestampsTz();
            $table->foreign('tenant_id')->references('id')->on('support_tenants')->cascadeOnDelete();
            $table->foreign('ticket_id')->references('id')->on('support_tickets')->cascadeOnDelete();
            $table->foreign('customer_actor_id')->references('id')->on('support_actors')->restrictOnDelete();
            $table->index(['tenant_id', 'created_at']);
        });

        Schema::create('support_agent_states', function (Blueprint $table): void {
            $table->string('tenant_id', 30);
            $table->string('admin_actor_id', 30);
            $table->boolean('available')->default(false);
            $table->unsignedSmallInteger('capacity')->nullable();
            $table->timestampTz('last_heartbeat_at')->nullable();
            $table->timestampTz('last_assigned_at')->nullable();
            $table->timestampsTz();
            $table->primary(['tenant_id', 'admin_actor_id']);
            $table->foreign('tenant_id')->references('id')->on('support_tenants')->cascadeOnDelete();
            $table->foreign('admin_actor_id')->references('id')->on('support_actors')->cascadeOnDelete();
            $table->index(['tenant_id', 'available', 'last_heartbeat_at']);
        });

        Schema::create('support_assignment_history', function (Blueprint $table): void {
            $table->string('id', 30)->primary();
            $table->string('tenant_id', 30);
            $table->string('ticket_id', 30);
            $table->string('from_admin_actor_id', 30)->nullable();
            $table->string('to_admin_actor_id', 30)->nullable();
            $table->string('assigned_by_type', 24);
            $table->string('assigned_by_actor_id', 30)->nullable();
            $table->string('reason', 500)->nullable();
            $table->timestampsTz();
            $table->foreign('tenant_id')->references('id')->on('support_tenants')->cascadeOnDelete();
            $table->foreign('ticket_id')->references('id')->on('support_tickets')->cascadeOnDelete();
            $table->index(['tenant_id', 'ticket_id', 'created_at']);
        });

        Schema::create('support_audit_logs', function (Blueprint $table): void {
            $table->string('id', 30)->primary();
            $table->string('tenant_id', 30);
            $table->string('actor_type', 24);
            $table->string('actor_external_id', 64)->nullable();
            $table->string('action', 120);
            $table->string('subject_type', 80);
            $table->string('subject_id', 64);
            $table->jsonb('metadata_json')->nullable();
            $table->string('request_id', 120)->nullable();
            $table->timestampsTz();
            $table->index(['tenant_id', 'action', 'created_at']);
            $table->index(['tenant_id', 'subject_type', 'subject_id']);
        });

        Schema::create('support_outbox', function (Blueprint $table): void {
            $table->string('id', 30)->primary();
            $table->string('tenant_id', 30);
            $table->string('event_key', 120);
            $table->string('aggregate_type', 80);
            $table->string('aggregate_id', 64);
            $table->string('dedupe_key', 160)->unique();
            $table->jsonb('payload_json');
            $table->string('status', 24)->default('pending');
            $table->unsignedSmallInteger('attempts')->default(0);
            $table->timestampTz('available_at');
            $table->timestampTz('delivered_at')->nullable();
            $table->string('last_error', 500)->nullable();
            $table->timestampsTz();
            $table->index(['status', 'available_at']);
            $table->index(['tenant_id', 'event_key', 'created_at']);
        });

        Schema::create('support_idempotency_records', function (Blueprint $table): void {
            $table->string('id', 30)->primary();
            $table->string('tenant_id', 30);
            $table->string('actor_id', 30);
            $table->string('operation', 120);
            $table->string('idempotency_key', 160);
            $table->string('payload_hash', 64);
            $table->unsignedSmallInteger('response_status')->nullable();
            $table->jsonb('response_json')->nullable();
            $table->timestampsTz();
            $table->unique(['tenant_id', 'actor_id', 'operation', 'idempotency_key']);
        });

        Schema::create('failed_jobs', function (Blueprint $table): void {
            $table->id();
            $table->string('uuid')->unique();
            $table->text('connection');
            $table->text('queue');
            $table->longText('payload');
            $table->longText('exception');
            $table->timestamp('failed_at')->useCurrent();
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('failed_jobs');
        Schema::dropIfExists('support_idempotency_records');
        Schema::dropIfExists('support_outbox');
        Schema::dropIfExists('support_audit_logs');
        Schema::dropIfExists('support_assignment_history');
        Schema::dropIfExists('support_agent_states');
        Schema::dropIfExists('support_ratings');
        Schema::dropIfExists('support_read_receipts');
        Schema::dropIfExists('support_attachments');
        Schema::dropIfExists('support_messages');
        Schema::dropIfExists('support_tickets');
        Schema::dropIfExists('support_faq_feedback');
        Schema::dropIfExists('support_faqs');
        Schema::dropIfExists('support_categories');
        Schema::dropIfExists('support_settings');
        Schema::dropIfExists('support_actors');
        Schema::dropIfExists('support_tenants');
    }
};
