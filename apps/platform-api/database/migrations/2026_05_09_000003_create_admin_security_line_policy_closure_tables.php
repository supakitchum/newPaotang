<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::create('admin_password_reset_tokens', function (Blueprint $table): void {
            $table->string('id', 30)->primary();
            $table->string('admin_user_id', 30);
            $table->string('email_hash', 64);
            $table->string('token_hash', 64)->unique();
            $table->string('status')->default('pending');
            $table->timestampTz('expires_at');
            $table->timestampTz('consumed_at')->nullable();
            $table->ipAddress('requested_ip')->nullable();
            $table->text('requested_user_agent')->nullable();
            $table->timestampsTz();

            $table->foreign('admin_user_id')->references('id')->on('admin_users')->cascadeOnDelete();
            $table->index(['admin_user_id', 'status', 'expires_at']);
            $table->index(['email_hash', 'created_at']);
        });

        Schema::create('admin_two_factor_settings', function (Blueprint $table): void {
            $table->string('id', 30)->primary();
            $table->string('admin_user_id', 30)->unique();
            $table->string('status')->default('pending');
            $table->text('secret_encrypted')->nullable();
            $table->unsignedInteger('secret_version')->default(1);
            $table->timestampTz('enabled_at')->nullable();
            $table->timestampTz('disabled_at')->nullable();
            $table->timestampTz('last_verified_at')->nullable();
            $table->json('metadata_json')->nullable();
            $table->timestampsTz();

            $table->foreign('admin_user_id')->references('id')->on('admin_users')->cascadeOnDelete();
            $table->index(['status', 'updated_at']);
        });

        Schema::create('admin_two_factor_recovery_codes', function (Blueprint $table): void {
            $table->string('id', 30)->primary();
            $table->string('admin_user_id', 30);
            $table->string('code_hash', 64)->unique();
            $table->timestampTz('used_at')->nullable();
            $table->timestampsTz();

            $table->foreign('admin_user_id')->references('id')->on('admin_users')->cascadeOnDelete();
            $table->index(['admin_user_id', 'used_at']);
        });

        Schema::create('admin_two_factor_challenges', function (Blueprint $table): void {
            $table->string('id', 30)->primary();
            $table->string('admin_user_id', 30);
            $table->string('challenge_token_hash', 64)->unique();
            $table->string('scope_type');
            $table->string('scope_id', 30)->nullable();
            $table->string('tenant_id', 30)->nullable();
            $table->string('status')->default('pending');
            $table->timestampTz('expires_at');
            $table->timestampTz('consumed_at')->nullable();
            $table->timestampsTz();

            $table->foreign('admin_user_id')->references('id')->on('admin_users')->cascadeOnDelete();
            $table->foreign('scope_id')->references('id')->on('admin_scopes')->nullOnDelete();
            $table->foreign('tenant_id')->references('id')->on('partner_tenants')->nullOnDelete();
            $table->index(['admin_user_id', 'status', 'expires_at']);
        });

        Schema::create('customer_external_auth_states', function (Blueprint $table): void {
            $table->string('id', 30)->primary();
            $table->string('tenant_id', 30);
            $table->string('provider');
            $table->string('state_hash', 64)->unique();
            $table->string('store_id')->nullable();
            $table->string('status')->default('pending');
            $table->text('redirect_uri')->nullable();
            $table->timestampTz('expires_at');
            $table->timestampTz('consumed_at')->nullable();
            $table->json('metadata_json')->nullable();
            $table->timestampsTz();

            $table->foreign('tenant_id')->references('id')->on('partner_tenants')->cascadeOnDelete();
            $table->index(['tenant_id', 'provider', 'status', 'expires_at']);
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('customer_external_auth_states');
        Schema::dropIfExists('admin_two_factor_challenges');
        Schema::dropIfExists('admin_two_factor_recovery_codes');
        Schema::dropIfExists('admin_two_factor_settings');
        Schema::dropIfExists('admin_password_reset_tokens');
    }
};
