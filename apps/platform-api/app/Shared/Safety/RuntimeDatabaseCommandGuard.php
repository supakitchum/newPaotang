<?php

namespace App\Shared\Safety;

use RuntimeException;

final class RuntimeDatabaseCommandGuard
{
    public const BYPASS_TOKEN = 'I_UNDERSTAND_THIS_WILL_DESTROY_RUNTIME_DATA';

    /**
     * @param array<int, string> $unsafeCommands
     * @param array<int, string> $testDatabaseSuffixes
     */
    public function __construct(
        private readonly array $unsafeCommands,
        private readonly array $testDatabaseSuffixes,
        private readonly string $bypassToken = self::BYPASS_TOKEN,
    ) {}

    public static function fromConfig(): self
    {
        return new self(
            array_values(array_filter(array_map('strval', (array) config('platform.database_guard.unsafe_commands', [])))),
            array_values(array_filter(array_map('strval', (array) config('platform.database_guard.test_database_suffixes', ['_test'])))),
            (string) config('platform.database_guard.bypass_token', self::BYPASS_TOKEN),
        );
    }

    public function assertAllowed(?string $command, ?string $database, ?string $environment, ?string $bypassValue = null): void
    {
        $command = trim((string) $command);

        if ($command === '' || ! in_array($command, $this->unsafeCommands, true)) {
            return;
        }

        if ($bypassValue !== null && hash_equals($this->bypassToken, $bypassValue)) {
            return;
        }

        $database = trim((string) $database);

        if ($this->isTestDatabase($database)) {
            return;
        }

        $environment = trim((string) $environment);

        throw new RuntimeException(sprintf(
            'Blocked unsafe Artisan command [%s] for database [%s] in environment [%s]. Destructive DB commands must target a test database such as newpaotang_test. Run tests with: docker compose run --rm -e APP_ENV=testing -e DB_DATABASE=newpaotang_test platform-api php artisan ... --env=testing. For an intentional one-time runtime reset only, set PLATFORM_ALLOW_DESTRUCTIVE_DB_COMMANDS=%s explicitly for that command.',
            $command,
            $database !== '' ? $database : 'unknown',
            $environment !== '' ? $environment : 'unknown',
            self::BYPASS_TOKEN,
        ));
    }

    private function isTestDatabase(string $database): bool
    {
        $database = strtolower(trim($database));

        if ($database === '') {
            return false;
        }

        foreach ($this->testDatabaseSuffixes as $suffix) {
            $suffix = strtolower(trim($suffix));

            if ($suffix !== '' && str_ends_with($database, $suffix)) {
                return true;
            }
        }

        return false;
    }
}
