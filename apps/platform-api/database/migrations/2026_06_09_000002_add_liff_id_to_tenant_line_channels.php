<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        if (! Schema::hasTable('tenant_line_channels') || Schema::hasColumn('tenant_line_channels', 'liff_id')) {
            return;
        }

        Schema::table('tenant_line_channels', function (Blueprint $table): void {
            $table->string('liff_id', 80)->nullable()->after('login_channel_secret_encrypted');
        });
    }

    public function down(): void
    {
        if (! Schema::hasTable('tenant_line_channels') || ! Schema::hasColumn('tenant_line_channels', 'liff_id')) {
            return;
        }

        Schema::table('tenant_line_channels', function (Blueprint $table): void {
            $table->dropColumn('liff_id');
        });
    }
};
