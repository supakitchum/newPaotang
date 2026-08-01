<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::create('admin_user_invitations', function (Blueprint $table): void {
            $table->string('id', 30)->primary();
            $table->string('admin_user_id', 30);
            $table->string('scope_type');
            $table->string('tenant_id', 30)->nullable();
            $table->string('token_hash', 64)->unique();
            $table->string('status')->default('pending');
            $table->timestampTz('expires_at');
            $table->timestampTz('accepted_at')->nullable();
            $table->string('created_by_admin_id', 30)->nullable();
            $table->timestampsTz();

            $table->foreign('admin_user_id')->references('id')->on('admin_users')->cascadeOnDelete();
            $table->foreign('tenant_id')->references('id')->on('partner_tenants')->nullOnDelete();
            $table->foreign('created_by_admin_id')->references('id')->on('admin_users')->nullOnDelete();
            $table->index(['admin_user_id', 'status', 'expires_at'], 'admin_user_invitations_user_status_index');
            $table->index(['tenant_id', 'status', 'expires_at'], 'admin_user_invitations_tenant_status_index');
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('admin_user_invitations');
    }
};
