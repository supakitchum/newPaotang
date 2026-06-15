<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::create('customer_password_reset_requests', function (Blueprint $table): void {
            $table->string('id', 30)->primary();
            $table->string('tenant_id', 30);
            $table->string('customer_id', 30)->nullable();
            $table->string('channel')->default('admin_request');
            $table->string('status')->default('submitted');
            $table->string('requested_identifier')->nullable();
            $table->string('phone')->nullable();
            $table->string('email')->nullable();
            $table->string('reset_token_hash', 64)->nullable()->unique();
            $table->timestampTz('link_issued_at')->nullable();
            $table->timestampTz('expires_at')->nullable();
            $table->timestampTz('consumed_at')->nullable();
            $table->string('issued_by_admin_id', 30)->nullable();
            $table->string('requested_ip')->nullable();
            $table->text('requested_user_agent')->nullable();
            $table->json('metadata_json')->nullable();
            $table->timestampsTz();

            $table->foreign('tenant_id')->references('id')->on('partner_tenants')->cascadeOnDelete();
            $table->foreign('customer_id')->references('id')->on('customers')->nullOnDelete();
            $table->foreign('issued_by_admin_id')->references('id')->on('admin_users')->nullOnDelete();
            $table->index(['tenant_id', 'status', 'created_at']);
            $table->index(['tenant_id', 'customer_id', 'status']);
            $table->index(['tenant_id', 'expires_at']);
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('customer_password_reset_requests');
    }
};
