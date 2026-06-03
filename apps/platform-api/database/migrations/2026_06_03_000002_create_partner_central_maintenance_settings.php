<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::create('partner_central_maintenance_settings', function (Blueprint $table): void {
            $table->string('id', 30)->primary();
            $table->string('partner_id', 30)->unique();
            $table->string('status')->default('inactive');
            $table->text('message')->nullable();
            $table->text('reason')->nullable();
            $table->string('ticket_id')->nullable();
            $table->timestampTz('scheduled_start_at')->nullable();
            $table->timestampTz('started_at')->nullable();
            $table->timestampTz('expected_end_at')->nullable();
            $table->timestampTz('ended_at')->nullable();
            $table->unsignedInteger('retry_after_seconds')->nullable();
            $table->string('created_by_admin_id', 30)->nullable();
            $table->string('updated_by_admin_id', 30)->nullable();
            $table->timestampsTz();

            $table->foreign('partner_id')->references('id')->on('partners')->cascadeOnDelete();
            $table->foreign('created_by_admin_id')->references('id')->on('admin_users')->nullOnDelete();
            $table->foreign('updated_by_admin_id')->references('id')->on('admin_users')->nullOnDelete();
            $table->index(['partner_id', 'status']);
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('partner_central_maintenance_settings');
    }
};
