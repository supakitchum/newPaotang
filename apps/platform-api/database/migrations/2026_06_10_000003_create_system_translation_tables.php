<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::create('system_languages', function (Blueprint $table): void {
            $table->string('id', 30)->primary();
            $table->string('locale', 20)->unique();
            $table->string('name');
            $table->string('native_name');
            $table->string('status')->default('active');
            $table->boolean('is_default')->default(false);
            $table->integer('sort_order')->default(0);
            $table->timestampsTz();

            $table->index(['status', 'sort_order']);
        });

        Schema::create('system_translation_keys', function (Blueprint $table): void {
            $table->string('id', 30)->primary();
            $table->string('translation_key')->unique();
            $table->string('surface', 40);
            $table->string('category', 80);
            $table->text('default_text')->nullable();
            $table->text('description')->nullable();
            $table->json('variables_json')->nullable();
            $table->string('status')->default('active');
            $table->timestampsTz();

            $table->index(['surface', 'category', 'status'], 'translation_keys_surface_category_status');
        });

        Schema::create('system_translation_values', function (Blueprint $table): void {
            $table->string('id', 30)->primary();
            $table->string('language_id', 30);
            $table->string('translation_key_id', 30);
            $table->text('value')->nullable();
            $table->string('published_by_admin_id', 30)->nullable();
            $table->timestampTz('published_at')->nullable();
            $table->timestampsTz();

            $table->foreign('language_id')->references('id')->on('system_languages')->cascadeOnDelete();
            $table->foreign('translation_key_id')->references('id')->on('system_translation_keys')->cascadeOnDelete();
            $table->foreign('published_by_admin_id')->references('id')->on('admin_users')->nullOnDelete();
            $table->unique(['language_id', 'translation_key_id'], 'translation_values_language_key_unique');
        });

        Schema::create('system_translation_drafts', function (Blueprint $table): void {
            $table->string('id', 30)->primary();
            $table->string('language_id', 30);
            $table->string('translation_key_id', 30);
            $table->text('value')->nullable();
            $table->string('status')->default('draft');
            $table->string('updated_by_admin_id', 30)->nullable();
            $table->timestampsTz();

            $table->foreign('language_id')->references('id')->on('system_languages')->cascadeOnDelete();
            $table->foreign('translation_key_id')->references('id')->on('system_translation_keys')->cascadeOnDelete();
            $table->foreign('updated_by_admin_id')->references('id')->on('admin_users')->nullOnDelete();
            $table->unique(['language_id', 'translation_key_id'], 'translation_drafts_language_key_unique');
            $table->index(['status', 'updated_at']);
        });

        Schema::create('system_translation_deploy_requests', function (Blueprint $table): void {
            $table->string('id', 30)->primary();
            $table->string('language_id', 30);
            $table->string('locale', 20);
            $table->string('surface', 40);
            $table->string('category', 80);
            $table->string('status')->default('draft');
            $table->string('title')->nullable();
            $table->json('summary_json')->nullable();
            $table->string('submitted_by_admin_id', 30)->nullable();
            $table->timestampTz('submitted_at')->nullable();
            $table->string('reviewed_by_admin_id', 30)->nullable();
            $table->timestampTz('reviewed_at')->nullable();
            $table->text('review_note')->nullable();
            $table->timestampTz('deployed_at')->nullable();
            $table->timestampsTz();

            $table->foreign('language_id')->references('id')->on('system_languages')->cascadeOnDelete();
            $table->foreign('submitted_by_admin_id')->references('id')->on('admin_users')->nullOnDelete();
            $table->foreign('reviewed_by_admin_id')->references('id')->on('admin_users')->nullOnDelete();
            $table->index(['status', 'surface', 'category'], 'translation_requests_status_surface_category');
            $table->index(['locale', 'surface', 'category'], 'translation_requests_locale_surface_category');
        });

        Schema::create('system_translation_deploy_request_items', function (Blueprint $table): void {
            $table->string('id', 30)->primary();
            $table->string('deploy_request_id', 30);
            $table->string('translation_key_id', 30);
            $table->text('current_value')->nullable();
            $table->text('draft_value')->nullable();
            $table->json('variables_json')->nullable();
            $table->json('validation_errors_json')->nullable();
            $table->timestampsTz();

            $table->foreign('deploy_request_id')->references('id')->on('system_translation_deploy_requests')->cascadeOnDelete();
            $table->foreign('translation_key_id')->references('id')->on('system_translation_keys')->cascadeOnDelete();
            $table->unique(['deploy_request_id', 'translation_key_id'], 'translation_request_items_request_key_unique');
        });

        Schema::create('system_translation_preview_sessions', function (Blueprint $table): void {
            $table->string('id', 30)->primary();
            $table->string('deploy_request_id', 30);
            $table->string('token_hash', 128)->unique();
            $table->string('created_by_admin_id', 30);
            $table->timestampTz('expires_at');
            $table->timestampTz('used_at')->nullable();
            $table->timestampsTz();

            $table->foreign('deploy_request_id')->references('id')->on('system_translation_deploy_requests')->cascadeOnDelete();
            $table->foreign('created_by_admin_id')->references('id')->on('admin_users')->cascadeOnDelete();
            $table->index(['expires_at']);
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('system_translation_preview_sessions');
        Schema::dropIfExists('system_translation_deploy_request_items');
        Schema::dropIfExists('system_translation_deploy_requests');
        Schema::dropIfExists('system_translation_drafts');
        Schema::dropIfExists('system_translation_values');
        Schema::dropIfExists('system_translation_keys');
        Schema::dropIfExists('system_languages');
    }
};
