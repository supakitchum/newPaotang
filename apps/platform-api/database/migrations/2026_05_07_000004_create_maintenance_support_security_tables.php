<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::create('partner_tenant_maintenance_settings', function (Blueprint $table): void {
            $table->string('id', 30)->primary();
            $table->string('tenant_id', 30)->unique();
            $table->string('status')->default('inactive');
            $table->string('mode')->default('scheduled');
            $table->text('message')->nullable();
            $table->text('reason')->nullable();
            $table->string('ticket_id')->nullable();
            $table->timestampTz('scheduled_start_at')->nullable();
            $table->timestampTz('started_at')->nullable();
            $table->timestampTz('expected_end_at')->nullable();
            $table->timestampTz('ended_at')->nullable();
            $table->unsignedInteger('retry_after_seconds')->nullable();
            $table->json('allowed_routes_json')->nullable();
            $table->json('blocked_route_patterns_json')->nullable();
            $table->string('created_by_admin_id', 30)->nullable();
            $table->string('updated_by_admin_id', 30)->nullable();
            $table->timestampsTz();

            $table->foreign('tenant_id')->references('id')->on('partner_tenants')->cascadeOnDelete();
            $table->foreign('created_by_admin_id')->references('id')->on('admin_users')->nullOnDelete();
            $table->foreign('updated_by_admin_id')->references('id')->on('admin_users')->nullOnDelete();
            $table->index(['tenant_id', 'status']);
        });

        Schema::create('partner_tenant_maintenance_events', function (Blueprint $table): void {
            $table->string('id', 30)->primary();
            $table->string('tenant_id', 30);
            $table->string('maintenance_setting_id', 30)->nullable();
            $table->string('event_type');
            $table->string('status')->nullable();
            $table->string('mode')->nullable();
            $table->text('reason')->nullable();
            $table->string('ticket_id')->nullable();
            $table->string('actor_admin_id', 30)->nullable();
            $table->json('payload_json')->nullable();
            $table->timestampsTz();

            $table->foreign('tenant_id')->references('id')->on('partner_tenants')->cascadeOnDelete();
            $table->foreign('maintenance_setting_id')->references('id')->on('partner_tenant_maintenance_settings')->nullOnDelete();
            $table->foreign('actor_admin_id')->references('id')->on('admin_users')->nullOnDelete();
            $table->index(['tenant_id', 'created_at']);
            $table->index(['tenant_id', 'event_type', 'created_at']);
        });

        Schema::create('partner_tenant_maintenance_bypasses', function (Blueprint $table): void {
            $table->string('id', 30)->primary();
            $table->string('tenant_id', 30);
            $table->string('bypass_type')->default('actor');
            $table->string('actor_type');
            $table->string('actor_id', 64);
            $table->string('support_impersonation_session_id', 30)->nullable();
            $table->string('status')->default('active');
            $table->text('reason')->nullable();
            $table->string('ticket_id')->nullable();
            $table->timestampTz('expires_at')->nullable();
            $table->timestampTz('revoked_at')->nullable();
            $table->string('created_by_admin_id', 30)->nullable();
            $table->string('revoked_by_admin_id', 30)->nullable();
            $table->json('metadata_json')->nullable();
            $table->timestampsTz();

            $table->foreign('tenant_id')->references('id')->on('partner_tenants')->cascadeOnDelete();
            $table->foreign('created_by_admin_id')->references('id')->on('admin_users')->nullOnDelete();
            $table->foreign('revoked_by_admin_id')->references('id')->on('admin_users')->nullOnDelete();
            $table->index(['tenant_id', 'status', 'expires_at']);
            $table->index(['tenant_id', 'actor_type', 'actor_id']);
        });

        Schema::create('support_access_requests', function (Blueprint $table): void {
            $table->string('id', 30)->primary();
            $table->string('tenant_id', 30);
            $table->string('target_user_id', 30);
            $table->string('target_user_type');
            $table->string('scope');
            $table->string('status')->default('pending_approval');
            $table->text('reason');
            $table->string('ticket_id');
            $table->string('requested_by_admin_id', 30);
            $table->string('approved_by_admin_id', 30)->nullable();
            $table->timestampTz('approved_at')->nullable();
            $table->string('revoked_by_admin_id', 30)->nullable();
            $table->timestampTz('revoked_at')->nullable();
            $table->timestampTz('completed_at')->nullable();
            $table->timestampTz('expires_at')->nullable();
            $table->json('metadata_json')->nullable();
            $table->timestampsTz();

            $table->foreign('tenant_id')->references('id')->on('partner_tenants')->cascadeOnDelete();
            $table->foreign('requested_by_admin_id')->references('id')->on('admin_users')->cascadeOnDelete();
            $table->foreign('approved_by_admin_id')->references('id')->on('admin_users')->nullOnDelete();
            $table->foreign('revoked_by_admin_id')->references('id')->on('admin_users')->nullOnDelete();
            $table->index(['tenant_id', 'status', 'created_at']);
            $table->index(['tenant_id', 'target_user_type', 'target_user_id']);
        });

        Schema::create('support_access_approvals', function (Blueprint $table): void {
            $table->string('id', 30)->primary();
            $table->string('tenant_id', 30);
            $table->string('support_access_request_id', 30);
            $table->string('action');
            $table->string('status')->default('accepted');
            $table->text('reason');
            $table->string('actor_admin_id', 30);
            $table->json('metadata_json')->nullable();
            $table->timestampsTz();

            $table->foreign('tenant_id')->references('id')->on('partner_tenants')->cascadeOnDelete();
            $table->foreign('support_access_request_id')->references('id')->on('support_access_requests')->cascadeOnDelete();
            $table->foreign('actor_admin_id')->references('id')->on('admin_users')->cascadeOnDelete();
            $table->index(['tenant_id', 'support_access_request_id', 'created_at']);
        });

        Schema::create('support_impersonation_sessions', function (Blueprint $table): void {
            $table->string('id', 30)->primary();
            $table->string('tenant_id', 30);
            $table->string('support_access_request_id', 30);
            $table->string('target_user_id', 30);
            $table->string('target_user_type');
            $table->string('scope');
            $table->string('status')->default('active');
            $table->string('token_hash', 64);
            $table->string('token_last_four', 4);
            $table->string('issued_to_admin_id', 30);
            $table->timestampTz('started_at');
            $table->timestampTz('expires_at');
            $table->timestampTz('revoked_at')->nullable();
            $table->timestampTz('ended_at')->nullable();
            $table->json('metadata_json')->nullable();
            $table->timestampsTz();

            $table->foreign('tenant_id')->references('id')->on('partner_tenants')->cascadeOnDelete();
            $table->foreign('support_access_request_id')->references('id')->on('support_access_requests')->cascadeOnDelete();
            $table->foreign('issued_to_admin_id')->references('id')->on('admin_users')->cascadeOnDelete();
            $table->index(['tenant_id', 'status', 'expires_at']);
            $table->index(['support_access_request_id', 'status']);
        });

        Schema::create('support_impersonation_events', function (Blueprint $table): void {
            $table->string('id', 30)->primary();
            $table->string('tenant_id', 30);
            $table->string('support_access_request_id', 30)->nullable();
            $table->string('support_impersonation_session_id', 30)->nullable();
            $table->string('event_type');
            $table->string('action')->nullable();
            $table->string('actor_admin_id', 30)->nullable();
            $table->string('target_user_id', 30)->nullable();
            $table->string('target_user_type')->nullable();
            $table->text('reason')->nullable();
            $table->json('metadata_json')->nullable();
            $table->timestampsTz();

            $table->foreign('tenant_id')->references('id')->on('partner_tenants')->cascadeOnDelete();
            $table->foreign('support_access_request_id')->references('id')->on('support_access_requests')->nullOnDelete();
            $table->foreign('support_impersonation_session_id')->references('id')->on('support_impersonation_sessions')->nullOnDelete();
            $table->foreign('actor_admin_id')->references('id')->on('admin_users')->nullOnDelete();
            $table->index(['tenant_id', 'event_type', 'created_at']);
        });

        Schema::create('support_impersonation_blocked_actions', function (Blueprint $table): void {
            $table->string('id', 30)->primary();
            $table->string('tenant_id', 30);
            $table->string('support_access_request_id', 30)->nullable();
            $table->string('support_impersonation_session_id', 30)->nullable();
            $table->string('action');
            $table->string('status')->default('blocked');
            $table->string('actor_admin_id', 30)->nullable();
            $table->string('route')->nullable();
            $table->text('reason')->nullable();
            $table->json('metadata_json')->nullable();
            $table->timestampsTz();

            $table->foreign('tenant_id')->references('id')->on('partner_tenants')->cascadeOnDelete();
            $table->foreign('support_access_request_id')->references('id')->on('support_access_requests')->nullOnDelete();
            $table->foreign('support_impersonation_session_id')->references('id')->on('support_impersonation_sessions')->nullOnDelete();
            $table->foreign('actor_admin_id')->references('id')->on('admin_users')->nullOnDelete();
            $table->index(['tenant_id', 'action', 'created_at']);
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('support_impersonation_blocked_actions');
        Schema::dropIfExists('support_impersonation_events');
        Schema::dropIfExists('support_impersonation_sessions');
        Schema::dropIfExists('support_access_approvals');
        Schema::dropIfExists('support_access_requests');
        Schema::dropIfExists('partner_tenant_maintenance_bypasses');
        Schema::dropIfExists('partner_tenant_maintenance_events');
        Schema::dropIfExists('partner_tenant_maintenance_settings');
    }
};
