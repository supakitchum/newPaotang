<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::create('tenant_social_auth_providers', function (Blueprint $table): void {
            $table->string('id', 30)->primary();
            $table->string('tenant_id', 30);
            $table->string('provider', 32);
            $table->string('status')->default('inactive');
            $table->text('client_id_encrypted')->nullable();
            $table->text('client_secret_encrypted')->nullable();
            $table->text('team_id_encrypted')->nullable();
            $table->text('key_id_encrypted')->nullable();
            $table->text('private_key_encrypted')->nullable();
            $table->text('redirect_uri')->nullable();
            $table->timestampTz('verified_at')->nullable();
            $table->timestampTz('last_tested_at')->nullable();
            $table->string('last_test_status')->nullable();
            $table->text('last_test_message')->nullable();
            $table->json('metadata_json')->nullable();
            $table->timestampsTz();

            $table->foreign('tenant_id')->references('id')->on('partner_tenants')->cascadeOnDelete();
            $table->unique(['tenant_id', 'provider']);
            $table->index(['tenant_id', 'status']);
        });

        Schema::create('customer_social_identities', function (Blueprint $table): void {
            $table->string('id', 30)->primary();
            $table->string('tenant_id', 30);
            $table->string('customer_id', 30);
            $table->string('provider', 32);
            $table->string('provider_user_id');
            $table->string('email')->nullable();
            $table->string('display_name')->nullable();
            $table->text('avatar_url')->nullable();
            $table->timestampTz('linked_at')->nullable();
            $table->timestampTz('last_login_at')->nullable();
            $table->json('metadata_json')->nullable();
            $table->timestampsTz();

            $table->foreign('tenant_id')->references('id')->on('partner_tenants')->cascadeOnDelete();
            $table->foreign('customer_id')->references('id')->on('customers')->cascadeOnDelete();
            $table->unique(['tenant_id', 'provider', 'provider_user_id'], 'customer_social_provider_user_unique');
            $table->unique(['tenant_id', 'customer_id', 'provider'], 'customer_social_customer_provider_unique');
            $table->index(['tenant_id', 'provider', 'email']);
        });

        Schema::create('customer_biometric_devices', function (Blueprint $table): void {
            $table->string('id', 30)->primary();
            $table->string('tenant_id', 30);
            $table->string('customer_id', 30);
            $table->string('device_id', 128);
            $table->string('platform', 32);
            $table->string('device_name')->nullable();
            $table->string('algorithm', 16)->default('ES256');
            $table->text('public_key_pem');
            $table->string('status')->default('active');
            $table->timestampTz('registered_at')->nullable();
            $table->timestampTz('last_used_at')->nullable();
            $table->timestampTz('revoked_at')->nullable();
            $table->json('metadata_json')->nullable();
            $table->timestampsTz();

            $table->foreign('tenant_id')->references('id')->on('partner_tenants')->cascadeOnDelete();
            $table->foreign('customer_id')->references('id')->on('customers')->cascadeOnDelete();
            $table->unique(['tenant_id', 'customer_id', 'device_id']);
            $table->index(['tenant_id', 'customer_id', 'status']);
        });

        Schema::create('customer_biometric_challenges', function (Blueprint $table): void {
            $table->string('id', 30)->primary();
            $table->string('tenant_id', 30);
            $table->string('customer_id', 30);
            $table->string('biometric_device_id', 30);
            $table->string('purpose', 64)->default('pin_unlock');
            $table->text('challenge');
            $table->string('status')->default('pending');
            $table->timestampTz('expires_at');
            $table->timestampTz('verified_at')->nullable();
            $table->json('metadata_json')->nullable();
            $table->timestampsTz();

            $table->foreign('tenant_id')->references('id')->on('partner_tenants')->cascadeOnDelete();
            $table->foreign('customer_id')->references('id')->on('customers')->cascadeOnDelete();
            $table->foreign('biometric_device_id')->references('id')->on('customer_biometric_devices')->cascadeOnDelete();
            $table->index(['tenant_id', 'customer_id', 'status']);
            $table->index(['tenant_id', 'expires_at']);
        });

        Schema::create('customer_pin_assertions', function (Blueprint $table): void {
            $table->string('id', 30)->primary();
            $table->string('tenant_id', 30);
            $table->string('customer_id', 30);
            $table->string('source_type', 32)->default('biometric');
            $table->string('source_id', 30)->nullable();
            $table->string('token_hash', 64);
            $table->string('purpose', 64)->default('pin_unlock');
            $table->string('status')->default('active');
            $table->timestampTz('expires_at');
            $table->timestampTz('consumed_at')->nullable();
            $table->json('metadata_json')->nullable();
            $table->timestampsTz();

            $table->foreign('tenant_id')->references('id')->on('partner_tenants')->cascadeOnDelete();
            $table->foreign('customer_id')->references('id')->on('customers')->cascadeOnDelete();
            $table->unique(['tenant_id', 'token_hash']);
            $table->index(['tenant_id', 'customer_id', 'status']);
            $table->index(['tenant_id', 'expires_at']);
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('customer_pin_assertions');
        Schema::dropIfExists('customer_biometric_challenges');
        Schema::dropIfExists('customer_biometric_devices');
        Schema::dropIfExists('customer_social_identities');
        Schema::dropIfExists('tenant_social_auth_providers');
    }
};
