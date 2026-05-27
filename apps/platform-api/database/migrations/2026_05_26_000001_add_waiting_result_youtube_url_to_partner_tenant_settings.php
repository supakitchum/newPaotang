<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::table('partner_tenant_settings', function (Blueprint $table): void {
            if (! Schema::hasColumn('partner_tenant_settings', 'waiting_result_youtube_url')) {
                $table->string('waiting_result_youtube_url', 2048)->nullable()->after('asset_cdn_base_url');
            }
        });
    }

    public function down(): void
    {
        Schema::table('partner_tenant_settings', function (Blueprint $table): void {
            if (Schema::hasColumn('partner_tenant_settings', 'waiting_result_youtube_url')) {
                $table->dropColumn('waiting_result_youtube_url');
            }
        });
    }
};
