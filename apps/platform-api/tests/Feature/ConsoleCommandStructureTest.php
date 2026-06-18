<?php

namespace Tests\Feature;

use App\Console\Commands\AutoCloseExpiredGamesCommand;
use App\Console\Commands\CalculateCommissionsCommand;
use App\Console\Commands\ExpireStockReservationsCommand;
use App\Console\Commands\PlatformAlertsCheckCommand;
use App\Console\Commands\PlatformAboutCommand;
use App\Console\Commands\PlatformCloudflareReadinessCommand;
use App\Console\Commands\PlatformMigrationRehearsalCommand;
use App\Console\Commands\PlatformObservabilityReportCommand;
use App\Console\Commands\PlatformRuntimeReadinessCommand;
use App\Console\Commands\PlatformSmokeCommand;
use App\Console\Commands\PrepareK6BaselineCommand;
use App\Console\Commands\PruneTopupSlipsCommand;
use App\Console\Commands\ProcessRewardCheckCommand;
use App\Console\Commands\ProcessSoldSyncCommand;
use App\Modules\CentralStock\Services\CentralStockService;
use App\Modules\Commerce\Services\CommerceService;
use App\Modules\Growth\Services\GrowthService;
use App\Modules\PartnerStore\Services\PartnerStoreService;
use App\Modules\Reward\Services\RewardService;
use Illuminate\Support\Facades\Artisan;
use Mockery\MockInterface;
use Symfony\Component\Console\Command\Command as SymfonyCommand;
use Tests\TestCase;

class ConsoleCommandStructureTest extends TestCase
{
    public function test_Console_Command_names_and_signatures_are_registered(): void
    {
        $commands = Artisan::all();

        $expectedClasses = [
            'platform:about' => PlatformAboutCommand::class,
            'platform:smoke' => PlatformSmokeCommand::class,
            'platform:observability:report' => PlatformObservabilityReportCommand::class,
            'platform:alerts:check' => PlatformAlertsCheckCommand::class,
            'platform:cloudflare:readiness' => PlatformCloudflareReadinessCommand::class,
            'platform:migration:rehearsal' => PlatformMigrationRehearsalCommand::class,
            'platform:runtime:readiness' => PlatformRuntimeReadinessCommand::class,
            'games:auto-close-expired' => AutoCloseExpiredGamesCommand::class,
            'stock:reservations:expire' => ExpireStockReservationsCommand::class,
            'stock:sold:sync' => ProcessSoldSyncCommand::class,
            'reward:check' => ProcessRewardCheckCommand::class,
            'commission:calculate' => CalculateCommissionsCommand::class,
            'topups:slips:prune' => PruneTopupSlipsCommand::class,
            'load-tests:k6:prepare' => PrepareK6BaselineCommand::class,
        ];

        foreach ($expectedClasses as $name => $class) {
            $this->assertArrayHasKey($name, $commands);
            $this->assertInstanceOf($class, $commands[$name]);
        }

        $this->assertSame('100', (string) $commands['stock:reservations:expire']->getDefinition()->getOption('limit')->getDefault());
        $this->assertSame('100', (string) $commands['games:auto-close-expired']->getDefinition()->getOption('limit')->getDefault());
        $this->assertSame('100', (string) $commands['stock:sold:sync']->getDefinition()->getOption('limit')->getDefault());
        $this->assertTrue($commands['platform:smoke']->getDefinition()->hasOption('no-seed-login'));
        $this->assertTrue($commands['platform:observability:report']->getDefinition()->hasOption('format'));
        $this->assertTrue($commands['platform:alerts:check']->getDefinition()->hasOption('dry-run'));
        $this->assertTrue($commands['platform:alerts:check']->getDefinition()->hasOption('format'));
        $this->assertTrue($commands['platform:cloudflare:readiness']->getDefinition()->hasOption('format'));
        $this->assertTrue($commands['platform:migration:rehearsal']->getDefinition()->hasOption('dry-run'));
        $this->assertTrue($commands['platform:migration:rehearsal']->getDefinition()->hasOption('format'));
        $this->assertTrue($commands['platform:runtime:readiness']->getDefinition()->hasOption('format'));

        $rewardDefinition = $commands['reward:check']->getDefinition();
        $this->assertTrue($rewardDefinition->hasArgument('reward_result_id'));
        $this->assertFalse($rewardDefinition->getArgument('reward_result_id')->isRequired());
        $this->assertSame('100', (string) $rewardDefinition->getOption('chunk')->getDefault());

        $commissionDefinition = $commands['commission:calculate']->getDefinition();
        $this->assertTrue($commissionDefinition->hasArgument('order_id'));
        $this->assertFalse($commissionDefinition->getArgument('order_id')->isRequired());
        $this->assertNull($commissionDefinition->getOption('tenant_id')->getDefault());
        $this->assertSame('100', (string) $commissionDefinition->getOption('limit')->getDefault());
        $this->assertSame('100', (string) $commands['topups:slips:prune']->getDefinition()->getOption('limit')->getDefault());

        $k6Definition = $commands['load-tests:k6:prepare']->getDefinition();
        $this->assertTrue($k6Definition->hasOption('output-json'));
        $this->assertTrue($k6Definition->hasOption('output-env'));
        $this->assertSame('http://host.docker.internal:8000', (string) $k6Definition->getOption('base-url')->getDefault());
        $this->assertSame('alpha.newpaotang.test', (string) $k6Definition->getOption('tenant-host')->getDefault());
    }

    public function test_Console_Command_classes_delegate_to_services_and_keep_output_shape(): void
    {
        $this->artisan('platform:about')
            ->expectsOutput('NewPaotang Platform API')
            ->assertExitCode(SymfonyCommand::SUCCESS);

        $this->mock(PartnerStoreService::class, function (MockInterface $mock): void {
            $mock->shouldReceive('expireReservations')->once()->with(7)->andReturn(3);
        });

        $this->artisan('stock:reservations:expire', ['--limit' => 7])
            ->expectsOutput('Expired reservations: 3')
            ->assertExitCode(SymfonyCommand::SUCCESS);

        $this->mock(CommerceService::class, function (MockInterface $mock): void {
            $mock->shouldReceive('processSoldSync')->once()->with(8)->andReturn(4);
        });

        $this->artisan('stock:sold:sync', ['--limit' => 8])
            ->expectsOutput('Processed sold events: 4')
            ->assertExitCode(SymfonyCommand::SUCCESS);

        $this->mock(CentralStockService::class, function (MockInterface $mock): void {
            $mock->shouldReceive('autoCloseExpiredGames')->once()->with(9)->andReturn([
                'closed_count' => 2,
                'closed_games' => [],
            ]);
        });

        $this->artisan('games:auto-close-expired', ['--limit' => 9])
            ->expectsOutput('Auto-closed games: 2')
            ->assertExitCode(SymfonyCommand::SUCCESS);

        $this->mock(CommerceService::class, function (MockInterface $mock): void {
            $mock->shouldReceive('pruneExpiredTopupSlips')->once()->with(11)->andReturn(6);
        });

        $this->artisan('topups:slips:prune', ['--limit' => 11])
            ->expectsOutput('Pruned topup slips: 6')
            ->assertExitCode(SymfonyCommand::SUCCESS);

        $this->mock(RewardService::class, function (MockInterface $mock): void {
            $mock->shouldReceive('processRewardCheck')->once()->with('rew_result_1', 9)->andReturn(5);
        });

        $this->artisan('reward:check', ['reward_result_id' => 'rew_result_1', '--chunk' => 9])
            ->expectsOutput('Processed reward tickets: 5')
            ->assertExitCode(SymfonyCommand::SUCCESS);

        $this->mock(GrowthService::class, function (MockInterface $mock): void {
            $mock->shouldReceive('calculateCommissions')->once()->with('ord_1', 'ten_1', 6)->andReturn(2);
        });

        $this->artisan('commission:calculate', ['order_id' => 'ord_1', '--tenant_id' => 'ten_1', '--limit' => 6])
            ->expectsOutput('Calculated commission transactions: 2')
            ->assertExitCode(SymfonyCommand::SUCCESS);
    }

    public function test_Console_bootstrap_and_controller_convention_are_documented(): void
    {
        $consoleRoutes = file_get_contents(base_path('routes/console.php'));

        $this->assertIsString($consoleRoutes);
        $this->assertStringNotContainsString('Artisan::command', $consoleRoutes);
        $this->assertStringContainsString('first-class command classes', $consoleRoutes);

        foreach ([
            'AdminOperations',
            'Auth',
            'CentralStock',
            'Commerce',
            'Growth',
            'Health',
            'Maintenance',
            'Partner',
            'PartnerStore',
            'PublicSite',
            'Rbac',
            'Reward',
            'SupportAccess',
            'Tenancy',
            'Webhook',
        ] as $module) {
            $this->assertDirectoryExists(base_path('app/Modules/'.$module.'/Http/Controllers'));
        }

        $this->assertDirectoryExists(base_path('app/Modules/Platform/Http/Controllers'));
        $this->assertSame([], glob(base_path('app/Modules/Platform/Http/Controllers/*.php')) ?: []);
        $this->assertDirectoryDoesNotExist(base_path('app/Http/Controllers'));

        $consoleDoc = file_get_contents(base_path('app/Console/README.md'));

        $this->assertIsString($consoleDoc);
        $this->assertStringContainsString('apps/platform-api/app/Modules/<Domain>/Http/Controllers', $consoleDoc);
        $this->assertStringContainsString('apps/platform-api/app/Console/Commands', $consoleDoc);
        $this->assertStringContainsString('Do not create a duplicate root', $consoleDoc);
    }
}
