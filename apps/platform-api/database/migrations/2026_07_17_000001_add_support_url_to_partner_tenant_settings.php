<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::table('partner_tenant_settings', function (Blueprint $table): void {
            $table->string('support_url')->nullable()->after('support_phone');
        });
    }

    public function down(): void
    {
        Schema::table('partner_tenant_settings', function (Blueprint $table): void {
            $table->dropColumn('support_url');
        });
    }
};
