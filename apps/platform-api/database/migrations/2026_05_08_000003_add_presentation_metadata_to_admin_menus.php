<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::table('admin_menus', function (Blueprint $table): void {
            $table->string('category')->nullable();
            $table->string('icon')->nullable();
        });
    }

    public function down(): void
    {
        Schema::table('admin_menus', function (Blueprint $table): void {
            $table->dropColumn(['category', 'icon']);
        });
    }
};
