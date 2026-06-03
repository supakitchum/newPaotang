<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::create('public_visit_sessions', function (Blueprint $table): void {
            $table->string('id', 34)->primary();
            $table->string('tenant_id', 30);
            $table->string('partner_id', 30)->nullable();
            $table->string('customer_id', 30)->nullable();
            $table->string('visitor_key', 128);
            $table->string('session_key', 128);
            $table->string('source', 64)->default('direct');
            $table->string('channel', 96)->nullable();
            $table->string('path', 255)->nullable();
            $table->text('referrer')->nullable();
            $table->ipAddress('ip_address')->nullable();
            $table->text('user_agent')->nullable();
            $table->string('screen', 40)->nullable();
            $table->string('timezone', 80)->nullable();
            $table->timestampTz('first_seen_at');
            $table->timestampTz('last_seen_at');
            $table->timestampTz('expires_at');
            $table->json('metadata_json')->nullable();
            $table->timestampsTz();

            $table->foreign('tenant_id')->references('id')->on('partner_tenants')->cascadeOnDelete();
            $table->foreign('partner_id')->references('id')->on('partners')->nullOnDelete();
            $table->foreign('customer_id')->references('id')->on('customers')->nullOnDelete();
            $table->unique(['tenant_id', 'session_key'], 'public_visit_sessions_tenant_session_unique');
            $table->index(['tenant_id', 'last_seen_at'], 'public_visit_sessions_tenant_last_seen_index');
            $table->index(['partner_id', 'last_seen_at'], 'public_visit_sessions_partner_last_seen_index');
            $table->index(['source', 'last_seen_at'], 'public_visit_sessions_source_last_seen_index');
            $table->index(['customer_id', 'last_seen_at'], 'public_visit_sessions_customer_last_seen_index');
            $table->index('expires_at');
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('public_visit_sessions');
    }
};
