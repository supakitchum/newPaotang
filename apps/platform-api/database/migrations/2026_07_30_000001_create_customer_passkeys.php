<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::create('customer_passkeys', function (Blueprint $table): void {
            $table->string('id', 30)->primary();
            $table->string('tenant_id', 30);
            $table->string('user_id', 30);
            $table->string('name', 120);
            $table->text('credential_id');
            $table->json('credential');
            $table->string('status', 16)->default('active');
            $table->timestampTz('last_used_at')->nullable();
            $table->timestampTz('revoked_at')->nullable();
            $table->timestampsTz();

            $table->foreign('tenant_id')->references('id')->on('partner_tenants')->cascadeOnDelete();
            $table->foreign('user_id')->references('id')->on('customers')->cascadeOnDelete();
            $table->unique('credential_id', 'customer_passkeys_credential_unique');
            $table->index(['tenant_id', 'user_id', 'status'], 'customer_passkeys_customer_status_index');
        });

        Schema::create('customer_passkey_challenges', function (Blueprint $table): void {
            $table->string('id', 30)->primary();
            $table->string('tenant_id', 30);
            $table->string('customer_id', 30)->nullable();
            $table->string('ceremony', 24);
            $table->string('rp_id', 253);
            $table->json('allowed_origins_json');
            $table->json('options_json');
            $table->string('status', 16)->default('pending');
            $table->timestampTz('expires_at');
            $table->timestampTz('consumed_at')->nullable();
            $table->json('metadata_json')->nullable();
            $table->timestampsTz();

            $table->foreign('tenant_id')->references('id')->on('partner_tenants')->cascadeOnDelete();
            $table->foreign('customer_id')->references('id')->on('customers')->cascadeOnDelete();
            $table->index(['tenant_id', 'ceremony', 'status'], 'customer_passkey_challenges_status_index');
            $table->index(['tenant_id', 'expires_at'], 'customer_passkey_challenges_expiry_index');
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('customer_passkey_challenges');
        Schema::dropIfExists('customer_passkeys');
    }
};
