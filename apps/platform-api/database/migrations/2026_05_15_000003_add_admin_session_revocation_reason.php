<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::table('admin_auth_sessions', function (Blueprint $table): void {
            $table->string('revoked_reason', 50)->nullable()->after('revoked_at');
        });
    }

    public function down(): void
    {
        Schema::table('admin_auth_sessions', function (Blueprint $table): void {
            $table->dropColumn('revoked_reason');
        });
    }
};
