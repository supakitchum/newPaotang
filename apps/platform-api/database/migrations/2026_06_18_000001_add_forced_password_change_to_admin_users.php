<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::table('admin_users', function (Blueprint $table): void {
            if (! Schema::hasColumn('admin_users', 'must_change_password')) {
                $table->boolean('must_change_password')->default(true)->after('two_factor_enabled');
            }

            if (! Schema::hasColumn('admin_users', 'password_changed_at')) {
                $table->timestampTz('password_changed_at')->nullable()->after('must_change_password');
            }
        });
    }

    public function down(): void
    {
        Schema::table('admin_users', function (Blueprint $table): void {
            if (Schema::hasColumn('admin_users', 'password_changed_at')) {
                $table->dropColumn('password_changed_at');
            }

            if (Schema::hasColumn('admin_users', 'must_change_password')) {
                $table->dropColumn('must_change_password');
            }
        });
    }
};
