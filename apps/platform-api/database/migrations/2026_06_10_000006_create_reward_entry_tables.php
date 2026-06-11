<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::create('reward_entry_sessions', function (Blueprint $table): void {
            $table->string('id', 30)->primary();
            $table->string('game_id', 30);
            $table->string('status')->default('collecting');
            $table->json('expected_operators_json')->nullable();
            $table->unsignedInteger('expected_operator_count')->default(0);
            $table->unsignedInteger('submitted_count')->default(0);
            $table->json('scraper_snapshot_json')->nullable();
            $table->string('reward_result_id', 30)->nullable();
            $table->string('created_by_admin_id', 30)->nullable();
            $table->string('resolved_by_admin_id', 30)->nullable();
            $table->timestampTz('ready_at')->nullable();
            $table->timestampTz('resolved_at')->nullable();
            $table->timestampTz('cancelled_at')->nullable();
            $table->timestampsTz();

            $table->foreign('game_id')->references('id')->on('games')->cascadeOnDelete();
            $table->foreign('reward_result_id')->references('id')->on('reward_results')->nullOnDelete();
            $table->foreign('created_by_admin_id')->references('id')->on('admin_users')->nullOnDelete();
            $table->foreign('resolved_by_admin_id')->references('id')->on('admin_users')->nullOnDelete();
            $table->unique('game_id');
            $table->index(['status', 'created_at']);
        });

        Schema::create('reward_entry_submissions', function (Blueprint $table): void {
            $table->string('id', 30)->primary();
            $table->string('session_id', 30);
            $table->string('game_id', 30);
            $table->string('admin_user_id', 30);
            $table->string('status')->default('draft');
            $table->json('prizes_json')->nullable();
            $table->json('diff_to_scraper_json')->nullable();
            $table->timestampTz('submitted_at')->nullable();
            $table->timestampsTz();

            $table->foreign('session_id')->references('id')->on('reward_entry_sessions')->cascadeOnDelete();
            $table->foreign('game_id')->references('id')->on('games')->cascadeOnDelete();
            $table->foreign('admin_user_id')->references('id')->on('admin_users')->cascadeOnDelete();
            $table->unique(['session_id', 'admin_user_id']);
            $table->index(['session_id', 'status']);
        });

        Schema::create('reward_entry_resolutions', function (Blueprint $table): void {
            $table->string('id', 30)->primary();
            $table->string('session_id', 30);
            $table->string('game_id', 30);
            $table->string('reward_result_id', 30)->nullable();
            $table->string('selected_source_type');
            $table->string('selected_submission_id', 30)->nullable();
            $table->json('final_prizes_json');
            $table->text('reason')->nullable();
            $table->string('resolved_by_admin_id', 30);
            $table->timestampTz('resolved_at');
            $table->timestampsTz();

            $table->foreign('session_id')->references('id')->on('reward_entry_sessions')->cascadeOnDelete();
            $table->foreign('game_id')->references('id')->on('games')->cascadeOnDelete();
            $table->foreign('reward_result_id')->references('id')->on('reward_results')->nullOnDelete();
            $table->foreign('selected_submission_id')->references('id')->on('reward_entry_submissions')->nullOnDelete();
            $table->foreign('resolved_by_admin_id')->references('id')->on('admin_users')->cascadeOnDelete();
            $table->unique('session_id');
            $table->index(['game_id', 'resolved_at']);
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('reward_entry_resolutions');
        Schema::dropIfExists('reward_entry_submissions');
        Schema::dropIfExists('reward_entry_sessions');
    }
};
