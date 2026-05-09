<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::create('partners', function (Blueprint $table): void {
            $table->string('id', 30)->primary();
            $table->string('code')->unique();
            $table->string('name');
            $table->string('type')->default('partner_store');
            $table->string('status')->default('draft');
            $table->timestampsTz();
        });

        Schema::create('partner_tenants', function (Blueprint $table): void {
            $table->string('id', 30)->primary();
            $table->string('partner_id', 30);
            $table->string('code')->unique();
            $table->string('name');
            $table->string('status')->default('provisioning');
            $table->timestampsTz();
            $table->foreign('partner_id')->references('id')->on('partners')->cascadeOnDelete();
        });

        Schema::create('partner_tenant_domains', function (Blueprint $table): void {
            $table->string('id', 30)->primary();
            $table->string('partner_id', 30);
            $table->string('tenant_id', 30);
            $table->string('host')->unique();
            $table->string('type')->default('subdomain');
            $table->string('status')->default('pending_verification');
            $table->boolean('is_primary')->default(false);
            $table->timestampTz('verified_at')->nullable();
            $table->timestampTz('ssl_ready_at')->nullable();
            $table->timestampsTz();
            $table->foreign('partner_id')->references('id')->on('partners')->cascadeOnDelete();
            $table->foreign('tenant_id')->references('id')->on('partner_tenants')->cascadeOnDelete();
            $table->index(['host', 'status']);
        });

        Schema::create('admin_users', function (Blueprint $table): void {
            $table->string('id', 30)->primary();
            $table->string('email')->unique();
            $table->string('password_hash');
            $table->string('status')->default('invited');
            $table->timestampsTz();
        });

        Schema::create('admin_scopes', function (Blueprint $table): void {
            $table->string('id', 30)->primary();
            $table->string('scope_type');
            $table->string('tenant_id', 30)->nullable();
            $table->string('partner_id', 30)->nullable();
            $table->timestampsTz();
            $table->foreign('tenant_id')->references('id')->on('partner_tenants')->nullOnDelete();
            $table->foreign('partner_id')->references('id')->on('partners')->nullOnDelete();
            $table->index(['scope_type', 'tenant_id']);
        });

        Schema::create('roles', function (Blueprint $table): void {
            $table->string('id', 30)->primary();
            $table->string('scope_type');
            $table->string('tenant_id', 30)->nullable();
            $table->string('code');
            $table->string('name');
            $table->string('status')->default('active');
            $table->unsignedInteger('version')->default(1);
            $table->timestampsTz();
            $table->foreign('tenant_id')->references('id')->on('partner_tenants')->nullOnDelete();
            $table->unique(['scope_type', 'tenant_id', 'code']);
            $table->index(['scope_type', 'tenant_id', 'code']);
        });

        Schema::create('permissions', function (Blueprint $table): void {
            $table->string('id', 30)->primary();
            $table->string('scope_type');
            $table->string('code');
            $table->string('name');
            $table->string('status')->default('active');
            $table->timestampsTz();
            $table->unique(['scope_type', 'code']);
        });

        Schema::create('role_permissions', function (Blueprint $table): void {
            $table->string('role_id', 30);
            $table->string('permission_id', 30);
            $table->timestampsTz();
            $table->primary(['role_id', 'permission_id']);
            $table->foreign('role_id')->references('id')->on('roles')->cascadeOnDelete();
            $table->foreign('permission_id')->references('id')->on('permissions')->cascadeOnDelete();
        });

        Schema::create('admin_user_roles', function (Blueprint $table): void {
            $table->string('admin_user_id', 30);
            $table->string('role_id', 30);
            $table->string('scope_id', 30);
            $table->timestampsTz();
            $table->primary(['admin_user_id', 'role_id', 'scope_id']);
            $table->foreign('admin_user_id')->references('id')->on('admin_users')->cascadeOnDelete();
            $table->foreign('role_id')->references('id')->on('roles')->cascadeOnDelete();
            $table->foreign('scope_id')->references('id')->on('admin_scopes')->cascadeOnDelete();
        });

        Schema::create('admin_menus', function (Blueprint $table): void {
            $table->string('id', 30)->primary();
            $table->string('scope_type');
            $table->string('parent_id', 30)->nullable();
            $table->string('code');
            $table->string('label');
            $table->string('route')->nullable();
            $table->string('required_permission_code')->nullable();
            $table->integer('sort_order')->default(0);
            $table->string('status')->default('active');
            $table->timestampsTz();
            $table->unique(['scope_type', 'code']);
            $table->index('parent_id');
        });

        Schema::create('role_menus', function (Blueprint $table): void {
            $table->string('role_id', 30);
            $table->string('menu_id', 30);
            $table->timestampsTz();
            $table->primary(['role_id', 'menu_id']);
            $table->foreign('role_id')->references('id')->on('roles')->cascadeOnDelete();
            $table->foreign('menu_id')->references('id')->on('admin_menus')->cascadeOnDelete();
        });

        Schema::create('admin_permission_cache_versions', function (Blueprint $table): void {
            $table->string('id', 30)->primary();
            $table->string('admin_user_id', 30);
            $table->string('scope_id', 30);
            $table->unsignedInteger('version')->default(1);
            $table->timestampsTz();
            $table->foreign('admin_user_id')->references('id')->on('admin_users')->cascadeOnDelete();
            $table->foreign('scope_id')->references('id')->on('admin_scopes')->cascadeOnDelete();
            $table->unique(['admin_user_id', 'scope_id']);
        });

        Schema::create('audit_logs', function (Blueprint $table): void {
            $table->string('id', 34)->primary();
            $table->string('actor_type');
            $table->string('actor_id', 30);
            $table->string('scope_type');
            $table->string('tenant_id', 30)->nullable();
            $table->string('partner_id', 30)->nullable();
            $table->string('action');
            $table->string('target_type')->nullable();
            $table->string('target_id', 30)->nullable();
            $table->string('request_id')->nullable();
            $table->ipAddress('ip_address')->nullable();
            $table->text('user_agent')->nullable();
            $table->json('payload_redacted_json')->nullable();
            $table->timestampsTz();
            $table->foreign('tenant_id')->references('id')->on('partner_tenants')->nullOnDelete();
            $table->foreign('partner_id')->references('id')->on('partners')->nullOnDelete();
            $table->index(['tenant_id', 'action', 'created_at']);
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('audit_logs');
        Schema::dropIfExists('admin_permission_cache_versions');
        Schema::dropIfExists('role_menus');
        Schema::dropIfExists('admin_menus');
        Schema::dropIfExists('admin_user_roles');
        Schema::dropIfExists('role_permissions');
        Schema::dropIfExists('permissions');
        Schema::dropIfExists('roles');
        Schema::dropIfExists('admin_scopes');
        Schema::dropIfExists('admin_users');
        Schema::dropIfExists('partner_tenant_domains');
        Schema::dropIfExists('partner_tenants');
        Schema::dropIfExists('partners');
    }
};
