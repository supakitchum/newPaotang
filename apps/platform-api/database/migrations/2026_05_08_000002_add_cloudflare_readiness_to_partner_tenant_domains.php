<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::table('partner_tenant_domains', function (Blueprint $table): void {
            $table->timestampTz('dns_verified_at')->nullable()->after('ssl_ready_at');
            $table->timestampTz('cloudflare_proxy_verified_at')->nullable()->after('dns_verified_at');
            $table->timestampTz('https_enforced_at')->nullable()->after('cloudflare_proxy_verified_at');
            $table->timestampTz('cloudflare_readiness_checked_at')->nullable()->after('https_enforced_at');
        });
    }

    public function down(): void
    {
        Schema::table('partner_tenant_domains', function (Blueprint $table): void {
            $table->dropColumn([
                'dns_verified_at',
                'cloudflare_proxy_verified_at',
                'https_enforced_at',
                'cloudflare_readiness_checked_at',
            ]);
        });
    }
};
