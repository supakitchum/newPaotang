<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::table('partner_tenant_settings', function (Blueprint $table): void {
            if (! Schema::hasColumn('partner_tenant_settings', 'terms_content')) {
                $table->text('terms_content')->nullable()->after('waiting_result_youtube_url');
            }
        });
    }

    public function down(): void
    {
        Schema::table('partner_tenant_settings', function (Blueprint $table): void {
            if (Schema::hasColumn('partner_tenant_settings', 'terms_content')) {
                $table->dropColumn('terms_content');
            }
        });
    }
};
