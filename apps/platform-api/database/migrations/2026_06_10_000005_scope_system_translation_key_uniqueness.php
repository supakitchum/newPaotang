<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::table('system_translation_keys', function (Blueprint $table): void {
            $table->dropUnique('system_translation_keys_translation_key_unique');
            $table->unique(['surface', 'translation_key'], 'translation_keys_surface_key_unique');
        });
    }

    public function down(): void
    {
        Schema::table('system_translation_keys', function (Blueprint $table): void {
            $table->dropUnique('translation_keys_surface_key_unique');
            $table->unique('translation_key', 'system_translation_keys_translation_key_unique');
        });
    }
};
