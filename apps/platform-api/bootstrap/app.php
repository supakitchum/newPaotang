<?php

use App\Console\Commands\AutoCloseExpiredGamesCommand;
use App\Console\Commands\CalculateCommissionsCommand;
use App\Console\Commands\CheckPendingLotteryBackgroundsCommand;
use App\Console\Commands\ExpireStockReservationsCommand;
use App\Console\Commands\LotteryImageReadinessCommand;
use App\Console\Commands\PlatformAlertsCheckCommand;
use App\Console\Commands\PlatformAboutCommand;
use App\Console\Commands\PlatformCloudflareReadinessCommand;
use App\Console\Commands\PlatformMigrationRehearsalCommand;
use App\Console\Commands\PlatformObservabilityReportCommand;
use App\Console\Commands\PlatformRuntimeReadinessCommand;
use App\Console\Commands\PlatformSmokeCommand;
use App\Console\Commands\PrepareK6BaselineCommand;
use App\Console\Commands\PruneLotteryBackgroundAssetSetsCommand;
use App\Console\Commands\PruneTopupSlipsCommand;
use App\Console\Commands\ProcessRewardCheckCommand;
use App\Console\Commands\ProcessSoldSyncCommand;
use App\Console\Commands\RecoverCustomerNotificationDeliveriesCommand;
use App\Console\Commands\RecoverStaleLotteryBackgroundZipImportsCommand;
use App\Console\Commands\SeedBaseLotteryNumbersCommand;
use App\Console\Commands\SeedCustomerContentFixturesCommand;
use App\Console\Commands\SeedRuntimeMockDataCommand;
use App\Console\Commands\SyncStaticTranslationsCommand;
use App\Modules\SupportAccess\Http\Middleware\BlockSensitiveSupportImpersonation;
use App\Shared\Auth\Http\Middleware\AuthenticateAdmin;
use App\Shared\Auth\Http\Middleware\AuthenticateCustomer;
use App\Shared\Auth\Http\Middleware\RequireAdminScope;
use App\Shared\Localization\Http\Middleware\SetApiLocale;
use App\Shared\Tenancy\Http\Middleware\NormalizeRequestHost;
use App\Shared\Tenancy\Http\Middleware\ResolveTenantByHost;
use Illuminate\Foundation\Application;
use Illuminate\Foundation\Configuration\Exceptions;
use Illuminate\Foundation\Configuration\Middleware;
use Illuminate\Support\Facades\Route;

return Application::configure(basePath: dirname(__DIR__))
    ->withRouting(
        api: __DIR__.'/../routes/api.php',
        commands: __DIR__.'/../routes/console.php',
        apiPrefix: 'api/v1',
        health: null,
        then: fn () => Route::middleware('api')->group(__DIR__.'/../routes/health.php'),
    )
    ->withCommands([
        PlatformAboutCommand::class,
        PlatformSmokeCommand::class,
        PlatformObservabilityReportCommand::class,
        PlatformAlertsCheckCommand::class,
        PlatformCloudflareReadinessCommand::class,
        PlatformMigrationRehearsalCommand::class,
        PlatformRuntimeReadinessCommand::class,
        AutoCloseExpiredGamesCommand::class,
        ExpireStockReservationsCommand::class,
        SeedBaseLotteryNumbersCommand::class,
        SeedCustomerContentFixturesCommand::class,
        ProcessSoldSyncCommand::class,
        ProcessRewardCheckCommand::class,
        CalculateCommissionsCommand::class,
        PrepareK6BaselineCommand::class,
        CheckPendingLotteryBackgroundsCommand::class,
        LotteryImageReadinessCommand::class,
        PruneLotteryBackgroundAssetSetsCommand::class,
        PruneTopupSlipsCommand::class,
        RecoverCustomerNotificationDeliveriesCommand::class,
        RecoverStaleLotteryBackgroundZipImportsCommand::class,
        SeedRuntimeMockDataCommand::class,
        SyncStaticTranslationsCommand::class,
    ])
    ->withMiddleware(function (Middleware $middleware): void {
        $middleware->prepend(NormalizeRequestHost::class);
        $middleware->append(SetApiLocale::class);

        $middleware->alias([
            'admin.auth' => AuthenticateAdmin::class,
            'customer.auth' => AuthenticateCustomer::class,
            'admin.scope' => RequireAdminScope::class,
            'support.block' => BlockSensitiveSupportImpersonation::class,
            'tenant.host' => ResolveTenantByHost::class,
        ]);
    })
    ->withExceptions(function (Exceptions $exceptions): void {
        //
    })
    ->create();
