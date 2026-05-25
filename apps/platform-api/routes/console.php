<?php

use Illuminate\Support\Facades\Schedule;

// Production workflow commands are first-class command classes registered
// through bootstrap/app.php. Keep this file available for lightweight console
// bootstrapping only.

Schedule::command('stock:reservations:expire --limit=100')
    ->everyMinute()
    ->withoutOverlapping()
    ->description('Expire stale tenant stock reservations in bounded chunks.');

Schedule::command('stock:sold:sync --limit=100')
    ->everyMinute()
    ->withoutOverlapping()
    ->description('Consume stock sold events into Central Stock in bounded chunks.');

Schedule::command('reward:check --chunk=100')
    ->everyFiveMinutes()
    ->withoutOverlapping()
    ->description('Process queued reward checks in deterministic chunks.');

Schedule::command('commission:calculate --limit=100')
    ->everyTenMinutes()
    ->withoutOverlapping()
    ->description('Calculate pending affiliate commissions in bounded chunks.');

Schedule::command('topups:slips:prune --limit=100')
    ->daily()
    ->withoutOverlapping()
    ->description('Delete expired topup slip images after the 30-day retention window.');

Schedule::command('platform:alerts:check --dry-run --format=json')
    ->everyFiveMinutes()
    ->withoutOverlapping()
    ->description('Evaluate M10 alert policies in non-mutating dry-run mode.');
