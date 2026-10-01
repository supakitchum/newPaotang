<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        if (Schema::getConnection()->getDriverName() === 'pgsql') {
            DB::statement('ALTER TABLE audit_logs ALTER COLUMN target_id TYPE VARCHAR(191)');

            return;
        }

        Schema::table('audit_logs', function (Blueprint $table): void {
            $table->string('target_id', 191)->nullable()->change();
        });
    }

    public function down(): void
    {
        if (Schema::getConnection()->getDriverName() === 'pgsql') {
            DB::statement('ALTER TABLE audit_logs ALTER COLUMN target_id TYPE VARCHAR(30)');

            return;
        }

        Schema::table('audit_logs', function (Blueprint $table): void {
            $table->string('target_id', 30)->nullable()->change();
        });
    }
};
