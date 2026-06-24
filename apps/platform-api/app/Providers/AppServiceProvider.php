<?php

namespace App\Providers;

use App\Shared\Safety\RuntimeDatabaseCommandGuard;
use App\Shared\Tenancy\TenantContext;
use Illuminate\Console\Events\CommandStarting;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Support\Facades\Event;
use Illuminate\Support\ServiceProvider;

class AppServiceProvider extends ServiceProvider
{
    public function register(): void
    {
        $this->app->scoped(TenantContext::class, fn () => new TenantContext);
    }

    public function boot(): void
    {
        Model::preventSilentlyDiscardingAttributes(! $this->app->isProduction());

        if ($this->app->runningInConsole()) {
            Event::listen(CommandStarting::class, function (CommandStarting $event): void {
                $connection = (string) config('database.default');
                $database = config("database.connections.{$connection}.database");

                RuntimeDatabaseCommandGuard::fromConfig()->assertAllowed(
                    $event->command,
                    is_scalar($database) ? (string) $database : null,
                    $this->app->environment(),
                    env('PLATFORM_ALLOW_DESTRUCTIVE_DB_COMMANDS'),
                );
            });
        }
    }
}
