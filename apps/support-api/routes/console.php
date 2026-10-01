<?php

use App\Jobs\DeliverSupportOutbox;
use App\Jobs\DrainSupportQueue;
use Illuminate\Support\Facades\Schedule;

Schedule::call(fn () => DrainSupportQueue::dispatch())
    ->name('support.queue.drain')
    ->everyMinute()
    ->withoutOverlapping();
Schedule::call(fn () => DeliverSupportOutbox::dispatch())
    ->name('support.outbox.deliver')
    ->everyMinute()
    ->withoutOverlapping();
