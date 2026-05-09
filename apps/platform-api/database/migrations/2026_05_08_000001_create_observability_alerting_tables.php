<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::create('partner_usage_events', function (Blueprint $table): void {
            $table->string('id', 30)->primary();
            $table->string('partner_id', 30);
            $table->string('tenant_id', 30)->nullable();
            $table->string('meter_key');
            $table->unsignedBigInteger('quantity')->default(1);
            $table->json('labels_json')->nullable();
            $table->timestampTz('occurred_at');
            $table->timestampsTz();

            $table->foreign('partner_id')->references('id')->on('partners')->cascadeOnDelete();
            $table->foreign('tenant_id')->references('id')->on('partner_tenants')->nullOnDelete();
            $table->index(['partner_id', 'meter_key', 'occurred_at']);
            $table->index(['tenant_id', 'meter_key', 'occurred_at']);
        });

        Schema::create('partner_daily_usage_summaries', function (Blueprint $table): void {
            $table->string('id', 30)->primary();
            $table->string('partner_id', 30);
            $table->string('tenant_id', 30)->nullable();
            $table->date('usage_date');
            $table->unsignedBigInteger('api_request_count')->default(0);
            $table->unsignedBigInteger('booking_request_count')->default(0);
            $table->unsignedBigInteger('checkout_request_count')->default(0);
            $table->unsignedBigInteger('order_count')->default(0);
            $table->unsignedBigInteger('sold_ticket_count')->default(0);
            $table->decimal('image_bandwidth_gb', 12, 3)->default(0);
            $table->decimal('storage_gb', 12, 3)->default(0);
            $table->unsignedBigInteger('queue_job_count')->default(0);
            $table->unsignedBigInteger('rate_limited_count')->default(0);
            $table->unsignedBigInteger('error_count')->default(0);
            $table->unsignedBigInteger('sync_event_count')->default(0);
            $table->json('labels_json')->nullable();
            $table->timestampsTz();

            $table->foreign('partner_id')->references('id')->on('partners')->cascadeOnDelete();
            $table->foreign('tenant_id')->references('id')->on('partner_tenants')->nullOnDelete();
            $table->unique(['partner_id', 'tenant_id', 'usage_date']);
            $table->index(['partner_id', 'usage_date']);
            $table->index(['tenant_id', 'usage_date']);
        });

        Schema::create('partner_alert_events', function (Blueprint $table): void {
            $table->string('id', 30)->primary();
            $table->string('partner_id', 30);
            $table->string('tenant_id', 30)->nullable();
            $table->string('alert_policy_id', 30)->nullable();
            $table->string('policy_key');
            $table->string('severity')->default('warning');
            $table->string('status')->default('open');
            $table->string('channel')->default('database');
            $table->string('title');
            $table->text('message')->nullable();
            $table->json('labels_json')->nullable();
            $table->json('payload_redacted_json')->nullable();
            $table->boolean('dry_run')->default(false);
            $table->timestampTz('triggered_at');
            $table->timestampTz('delivered_at')->nullable();
            $table->timestampsTz();

            $table->foreign('partner_id')->references('id')->on('partners')->cascadeOnDelete();
            $table->foreign('tenant_id')->references('id')->on('partner_tenants')->nullOnDelete();
            $table->foreign('alert_policy_id')->references('id')->on('partner_alert_policies')->nullOnDelete();
            $table->index(['partner_id', 'policy_key', 'status']);
            $table->index(['tenant_id', 'policy_key', 'status']);
            $table->index(['status', 'triggered_at']);
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('partner_alert_events');
        Schema::dropIfExists('partner_daily_usage_summaries');
        Schema::dropIfExists('partner_usage_events');
    }
};
