<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::table('admin_users', function (Blueprint $table): void {
            $table->string('name')->nullable()->after('id');
            $table->string('phone')->nullable()->after('email');
            $table->boolean('two_factor_enabled')->default(false)->after('status');
        });

        Schema::create('admin_auth_sessions', function (Blueprint $table): void {
            $table->string('id', 34)->primary();
            $table->string('admin_user_id', 30);
            $table->string('access_token_hash', 64)->unique();
            $table->string('refresh_token_hash', 64)->unique();
            $table->string('scope_type');
            $table->string('scope_id', 30)->nullable();
            $table->string('tenant_id', 30)->nullable();
            $table->timestampTz('access_expires_at');
            $table->timestampTz('refresh_expires_at');
            $table->timestampTz('revoked_at')->nullable();
            $table->string('refreshed_from_id', 34)->nullable();
            $table->timestampTz('last_used_at')->nullable();
            $table->timestampsTz();

            $table->foreign('admin_user_id')->references('id')->on('admin_users')->cascadeOnDelete();
            $table->foreign('scope_id')->references('id')->on('admin_scopes')->nullOnDelete();
            $table->foreign('tenant_id')->references('id')->on('partner_tenants')->nullOnDelete();
            $table->index(['admin_user_id', 'scope_type']);
            $table->index(['tenant_id', 'revoked_at']);
            $table->index('access_expires_at');
            $table->index('refreshed_from_id');
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('admin_auth_sessions');

        Schema::table('admin_users', function (Blueprint $table): void {
            $table->dropColumn(['name', 'phone', 'two_factor_enabled']);
        });
    }
};
