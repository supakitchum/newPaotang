<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::create('platform_storage_connections', function (Blueprint $table): void {
            $table->string('id', 40)->primary();
            $table->string('provider', 40);
            $table->string('status')->default('inactive');
            $table->string('bucket')->nullable();
            $table->string('region')->nullable();
            $table->string('endpoint')->nullable();
            $table->string('url')->nullable();
            $table->string('root_prefix')->nullable();
            $table->string('visibility')->default('private');
            $table->boolean('use_path_style_endpoint')->default(false);
            $table->text('access_key_id_encrypted')->nullable();
            $table->text('secret_access_key_encrypted')->nullable();
            $table->text('session_token_encrypted')->nullable();
            $table->string('last_test_status')->nullable();
            $table->text('last_test_message')->nullable();
            $table->timestampTz('last_tested_at')->nullable();
            $table->timestampTz('verified_at')->nullable();
            $table->json('metadata_json')->nullable();
            $table->timestampsTz();

            $table->index(['provider', 'status']);
            $table->index(['last_test_status']);
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('platform_storage_connections');
    }
};
