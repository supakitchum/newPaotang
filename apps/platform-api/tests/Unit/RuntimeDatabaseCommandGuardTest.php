<?php

namespace Tests\Unit;

use App\Shared\Safety\RuntimeDatabaseCommandGuard;
use RuntimeException;
use Tests\TestCase;

class RuntimeDatabaseCommandGuardTest extends TestCase
{
    public function test_blocks_destructive_command_when_testing_env_still_points_to_runtime_database(): void
    {
        $guard = new RuntimeDatabaseCommandGuard(
            unsafeCommands: ['migrate:fresh'],
            testDatabaseSuffixes: ['_test'],
        );

        $this->expectException(RuntimeException::class);
        $this->expectExceptionMessage('Blocked unsafe Artisan command [migrate:fresh] for database [newpaotang]');

        $guard->assertAllowed('migrate:fresh', 'newpaotang', 'testing');
    }

    public function test_allows_destructive_command_when_database_is_test_database(): void
    {
        $guard = new RuntimeDatabaseCommandGuard(
            unsafeCommands: ['migrate:fresh'],
            testDatabaseSuffixes: ['_test'],
        );

        $guard->assertAllowed('migrate:fresh', 'newpaotang_test', 'testing');

        $this->assertTrue(true);
    }

    public function test_allows_one_time_runtime_override_only_with_explicit_bypass_token(): void
    {
        $guard = new RuntimeDatabaseCommandGuard(
            unsafeCommands: ['db:wipe'],
            testDatabaseSuffixes: ['_test'],
        );

        $guard->assertAllowed(
            'db:wipe',
            'newpaotang',
            'local',
            RuntimeDatabaseCommandGuard::BYPASS_TOKEN,
        );

        $this->assertTrue(true);
    }
}
