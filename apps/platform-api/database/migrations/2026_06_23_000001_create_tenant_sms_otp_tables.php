<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::create('tenant_sms_providers', function (Blueprint $table): void {
            $table->string('id', 30)->primary();
            $table->string('tenant_id', 30);
            $table->string('provider', 40)->default('thaibulk');
            $table->string('status')->default('inactive');
            $table->text('api_key_encrypted')->nullable();
            $table->text('api_secret_encrypted')->nullable();
            $table->string('sender_name', 32)->nullable();
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

        Schema::create('otp_verifications', function (Blueprint $table): void {
            $table->string('id', 30)->primary();
            $table->string('tenant_id', 30);
            $table->string('provider_id', 30)->nullable();
            $table->string('provider', 40)->default('thaibulk');
            $table->string('purpose', 40);
            $table->string('phone', 32);
            $table->string('phone_normalized', 32);
            $table->string('otp_hash', 255);
            $table->string('verification_token_hash', 64)->nullable()->unique();
            $table->string('status')->default('pending');
            $table->unsignedTinyInteger('attempts')->default(0);
            $table->unsignedTinyInteger('max_attempts')->default(5);
            $table->timestampTz('expires_at');
            $table->timestampTz('cooldown_until')->nullable();
            $table->timestampTz('verified_at')->nullable();
            $table->timestampTz('consumed_at')->nullable();
            $table->string('requested_ip')->nullable();
            $table->text('requested_user_agent')->nullable();
            $table->json('metadata_json')->nullable();
            $table->timestampsTz();

            $table->foreign('tenant_id')->references('id')->on('partner_tenants')->cascadeOnDelete();
            $table->foreign('provider_id')->references('id')->on('tenant_sms_providers')->nullOnDelete();
            $table->index(['tenant_id', 'phone_normalized', 'purpose', 'status']);
            $table->index(['tenant_id', 'expires_at']);
        });

        Schema::create('sms_delivery_logs', function (Blueprint $table): void {
            $table->string('id', 30)->primary();
            $table->string('tenant_id', 30);
            $table->string('provider_id', 30)->nullable();
            $table->string('provider', 40)->default('thaibulk');
            $table->string('purpose', 40);
            $table->string('phone_masked', 32)->nullable();
            $table->string('status')->default('queued');
            $table->unsignedSmallInteger('http_status')->nullable();
            $table->unsignedInteger('latency_ms')->nullable();
            $table->string('provider_message_id')->nullable();
            $table->text('error_message')->nullable();
            $table->json('request_json')->nullable();
            $table->json('response_json')->nullable();
            $table->timestampsTz();

            $table->foreign('tenant_id')->references('id')->on('partner_tenants')->cascadeOnDelete();
            $table->foreign('provider_id')->references('id')->on('tenant_sms_providers')->nullOnDelete();
            $table->index(['tenant_id', 'status', 'created_at']);
            $table->index(['tenant_id', 'purpose', 'created_at']);
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('sms_delivery_logs');
        Schema::dropIfExists('otp_verifications');
        Schema::dropIfExists('tenant_sms_providers');
    }
};
