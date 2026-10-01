<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::create('tenant_payment_provider_connections', function (Blueprint $table): void {
            $table->string('id', 30)->primary();
            $table->string('tenant_id', 30);
            $table->string('provider', 60);
            $table->string('status')->default('inactive');
            $table->text('api_key_encrypted')->nullable();
            $table->timestampTz('verified_at')->nullable();
            $table->timestampTz('last_tested_at')->nullable();
            $table->string('last_test_status')->nullable();
            $table->text('last_error')->nullable();
            $table->json('metadata_json')->nullable();
            $table->timestampsTz();

            $table->foreign('tenant_id')->references('id')->on('partner_tenants')->cascadeOnDelete();
            $table->unique(['tenant_id', 'provider']);
            $table->index(['tenant_id', 'status']);
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('tenant_payment_provider_connections');
    }
};
