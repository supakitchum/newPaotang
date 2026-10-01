<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::create('affiliate_referral_visits', function (Blueprint $table): void {
            $table->string('id', 30)->primary();
            $table->string('tenant_id', 30);
            $table->string('affiliate_account_id', 30);
            $table->string('affiliate_link_id', 30)->nullable();
            $table->string('affiliate_program_id', 30)->nullable();
            $table->string('visitor_key', 128);
            $table->string('ref_code', 64);
            $table->string('customer_id', 30)->nullable();
            $table->unsignedInteger('click_count')->default(1);
            $table->text('landing_url')->nullable();
            $table->timestampTz('clicked_at')->nullable();
            $table->timestampTz('last_clicked_at')->nullable();
            $table->timestampTz('registered_at')->nullable();
            $table->json('metadata_json')->nullable();
            $table->timestampsTz();

            $table->foreign('tenant_id')->references('id')->on('partner_tenants')->cascadeOnDelete();
            $table->foreign('affiliate_account_id')->references('id')->on('affiliate_accounts')->cascadeOnDelete();
            $table->foreign('affiliate_link_id')->references('id')->on('affiliate_links')->nullOnDelete();
            $table->foreign('affiliate_program_id')->references('id')->on('affiliate_programs')->nullOnDelete();
            $table->foreign('customer_id')->references('id')->on('customers')->nullOnDelete();
            $table->unique(['tenant_id', 'affiliate_account_id', 'visitor_key'], 'affiliate_referral_visits_unique');
            $table->index(['tenant_id', 'affiliate_account_id', 'registered_at'], 'affiliate_referral_visits_registered_index');
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('affiliate_referral_visits');
    }
};
