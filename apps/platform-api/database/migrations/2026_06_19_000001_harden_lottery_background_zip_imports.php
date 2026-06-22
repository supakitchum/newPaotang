<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::table('lottery_image_background_zip_imports', function (Blueprint $table): void {
            $table->string('current_step')->nullable()->after('progress_percent');
            $table->unsignedInteger('attempts')->default(0)->after('current_step');
            $table->unsignedInteger('max_attempts')->default(3)->after('attempts');
            $table->unsignedInteger('stale_after_seconds')->default(600)->after('max_attempts');
            $table->timestampTz('heartbeat_at')->nullable()->after('stale_after_seconds');
            $table->timestampTz('last_error_at')->nullable()->after('heartbeat_at');

            $table->index(['status', 'heartbeat_at'], 'lbzi_status_heartbeat_idx');
        });
    }

    public function down(): void
    {
        Schema::table('lottery_image_background_zip_imports', function (Blueprint $table): void {
            $table->dropIndex('lbzi_status_heartbeat_idx');
            $table->dropColumn([
                'current_step',
                'attempts',
                'max_attempts',
                'stale_after_seconds',
                'heartbeat_at',
                'last_error_at',
            ]);
        });
    }
};
