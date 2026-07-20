<?php

namespace App\Modules\CustomerNotifications\Listeners;

use App\Modules\Activities\Events\ActivityClaimUpdated;
use App\Modules\Commerce\Events\CustomerOrderUpdated;
use App\Modules\Commerce\Events\CustomerTopupUpdated;
use App\Modules\Commerce\Events\CustomerWalletUpdated;
use App\Modules\CustomerNotifications\Services\CustomerNotificationDomainEventService;
use App\Modules\Reward\Events\RewardClaimUpdated;
use Illuminate\Events\Dispatcher;

class CustomerNotificationDomainEventSubscriber
{
    public function __construct(private readonly CustomerNotificationDomainEventService $notifications)
    {
    }

    public function handleOrderUpdated(CustomerOrderUpdated $event): void
    {
        $this->notifications->orderUpdated($event->payload);
    }

    public function handleTopupUpdated(CustomerTopupUpdated $event): void
    {
        $this->notifications->topupUpdated($event->payload);
    }

    public function handleWalletUpdated(CustomerWalletUpdated $event): void
    {
        $this->notifications->walletUpdated($event->payload);
    }

    public function handleRewardClaimUpdated(RewardClaimUpdated $event): void
    {
        $this->notifications->rewardClaimUpdated($event->payload);
    }

    public function handleActivityClaimUpdated(ActivityClaimUpdated $event): void
    {
        $this->notifications->activityClaimUpdated($event->payload);
    }

    public function subscribe(Dispatcher $events): array
    {
        return [
            CustomerOrderUpdated::class => 'handleOrderUpdated',
            CustomerTopupUpdated::class => 'handleTopupUpdated',
            CustomerWalletUpdated::class => 'handleWalletUpdated',
            RewardClaimUpdated::class => 'handleRewardClaimUpdated',
            ActivityClaimUpdated::class => 'handleActivityClaimUpdated',
        ];
    }
}
