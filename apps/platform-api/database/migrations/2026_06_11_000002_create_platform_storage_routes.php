<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::create('platform_storage_routes', function (Blueprint $table): void {
            $table->string('route_key', 60)->primary();
            $table->string('label');
            $table->text('description')->nullable();
            $table->string('driver', 20)->default('local');
            $table->string('root_prefix')->nullable();
            $table->boolean('tenant_scoped')->default(true);
            $table->unsignedInteger('sort_order')->default(0);
            $table->json('metadata_json')->nullable();
            $table->timestampsTz();

            $table->index(['driver', 'sort_order']);
            $table->index(['tenant_scoped']);
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('platform_storage_routes');
    }
};
