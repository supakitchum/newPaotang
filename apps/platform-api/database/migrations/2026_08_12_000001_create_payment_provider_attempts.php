<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::create('payment_provider_attempts', function (Blueprint $table): void {
            $table->string('id', 34)->primary();
            $table->string('tenant_id', 30);
            $table->string('customer_id', 30)->nullable();
            $table->string('payment_id', 30)->nullable();
            $table->string('topup_request_id', 30)->nullable();
            $table->string('provider');
            $table->string('operation', 32);
            $table->string('channel', 32)->nullable();
            $table->string('status', 32)->default('initiated');
            $table->string('request_id', 128)->nullable();
            $table->string('idempotency_key_hash', 64)->nullable();
            $table->string('provider_reference1', 20)->nullable();
            $table->string('provider_reference2', 20)->nullable();
            $table->string('provider_reference3', 20)->nullable();
            $table->string('provider_reference4', 20)->nullable();
            $table->string('provider_transaction_reference', 128)->nullable();
            $table->string('application_error_code', 64)->nullable();
            $table->unsignedSmallInteger('provider_http_status')->nullable();
            $table->string('provider_code', 64)->nullable();
            $table->text('provider_message')->nullable();
            $table->string('response_classification', 32)->nullable();
            $table->unsignedInteger('latency_ms')->nullable();
            $table->timestampTz('attempted_at');
            $table->timestampTz('completed_at')->nullable();
            $table->timestampsTz();

            $table->foreign('tenant_id')->references('id')->on('partner_tenants')->cascadeOnDelete();
            $table->foreign('customer_id')->references('id')->on('customers')->nullOnDelete();
            $table->foreign('payment_id')->references('id')->on('payments')->nullOnDelete();
            $table->foreign('topup_request_id')->references('id')->on('topup_requests')->nullOnDelete();
            $table->unique(['provider', 'provider_reference1'], 'provider_attempt_reference1_unique');
            $table->index(['tenant_id', 'provider', 'status', 'created_at'], 'provider_attempt_tenant_status_index');
            $table->index(['request_id'], 'provider_attempt_request_id_index');
            $table->index(['payment_id'], 'provider_attempt_payment_index');
            $table->index(['topup_request_id'], 'provider_attempt_topup_index');
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('payment_provider_attempts');
    }
};
