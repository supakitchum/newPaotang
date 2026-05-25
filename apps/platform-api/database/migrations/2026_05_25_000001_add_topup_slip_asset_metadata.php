<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::table('topup_requests', function (Blueprint $table): void {
            $table->string('slip_thumb_url')->nullable()->after('slip_url');
            $table->string('slip_storage_path')->nullable()->after('slip_thumb_url');
            $table->string('slip_thumb_storage_path')->nullable()->after('slip_storage_path');
            $table->timestampTz('slip_expires_at')->nullable()->after('slip_thumb_storage_path');
        });
    }

    public function down(): void
    {
        Schema::table('topup_requests', function (Blueprint $table): void {
            $table->dropColumn([
                'slip_thumb_url',
                'slip_storage_path',
                'slip_thumb_storage_path',
                'slip_expires_at',
            ]);
        });
    }
};
