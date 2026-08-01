<?php

namespace App\Providers;

use App\Models\Customer;
use App\Models\CustomerPasskey;
use App\Modules\CustomerNotifications\Listeners\CustomerNotificationDomainEventSubscriber;
use App\Shared\Safety\RuntimeDatabaseCommandGuard;
use App\Shared\Tenancy\TenantContext;
use Illuminate\Console\Events\CommandStarting;
use Illuminate\Cache\RateLimiting\Limit;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Event;
use Illuminate\Support\Facades\RateLimiter;
use Illuminate\Support\ServiceProvider;
use Laravel\Passkeys\Passkeys;

class AppServiceProvider extends ServiceProvider
{
    public function register(): void
    {
        Passkeys::ignoreRoutes();
        Passkeys::useUserModel(Customer::class);
        Passkeys::usePasskeyModel(CustomerPasskey::class);

        $this->app->scoped(TenantContext::class, fn () => new TenantContext);
    }

    public function boot(): void
    {
        Model::preventSilentlyDiscardingAttributes(! $this->app->isProduction());
        Event::subscribe(CustomerNotificationDomainEventSubscriber::class);
        RateLimiter::for('affiliate-public-referral', function (Request $request): Limit {
            $scope = strtolower((string) $request->getHost()).'|'.(string) $request->ip();

            return Limit::perMinute(
                (int) config('affiliate.rate_limits.public_referral_clicks_per_minute', 60),
            )->by(hash('sha256', $scope));
        });
        RateLimiter::for('affiliate-customer-write', function (Request $request): Limit {
            $customer = $request->attributes->get('customer_session');
            $scope = $customer instanceof \App\Shared\Auth\CustomerSessionContext
                ? $customer->tenantId().'|'.$customer->customerId()
                : strtolower((string) $request->getHost()).'|'.(string) $request->ip();

            return Limit::perMinute(
                (int) config('affiliate.rate_limits.customer_writes_per_minute', 20),
            )->by(hash('sha256', $scope));
        });
        RateLimiter::for('payment-webhook', function (Request $request): Limit {
            $scope = strtolower((string) $request->route('provider')).'|'.(string) $request->ip();

            return Limit::perMinute(300)->by(hash('sha256', $scope));
        });
        RateLimiter::for('admin-invitation', function (Request $request): Limit {
            return Limit::perMinute(30)->by(hash('sha256', (string) $request->ip()));
        });
        RateLimiter::for('customer-passkey-public', function (Request $request): Limit {
            $scope = strtolower((string) $request->getHost()).'|'.(string) $request->ip();

            return Limit::perMinute(12)->by(hash('sha256', $scope));
        });
        RateLimiter::for('customer-passkey-management', function (Request $request): Limit {
            $customer = $request->attributes->get('customer_session');
            $scope = $customer instanceof \App\Shared\Auth\CustomerSessionContext
                ? $customer->tenantId().'|'.$customer->customerId()
                : strtolower((string) $request->getHost()).'|'.(string) $request->ip();

            return Limit::perMinute(20)->by(hash('sha256', $scope));
        });

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
