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

Schedule::command('games:auto-close-expired --limit=100')
    ->everyMinute()
    ->withoutOverlapping()
    ->description('Automatically close open games 30 minutes after sale close.');

Schedule::command('reward:check --chunk=100')
    ->everyFiveMinutes()
    ->withoutOverlapping()
    ->description('Process queued reward checks in deterministic chunks.');

Schedule::command('commission:calculate --limit=100')
    ->everyTenMinutes()
    ->withoutOverlapping()
    ->onOneServer()
    ->description('Calculate pending affiliate commissions in bounded chunks.');

Schedule::command('affiliate-tier-campaigns:finalize --limit=25')
    ->everyMinute()
    ->withoutOverlapping()
    ->onOneServer()
    ->description('Activate and finalize affiliate tier campaigns at their configured times.');

Schedule::command('topups:slips:prune --limit=100')
    ->daily()
    ->withoutOverlapping()
    ->description('Delete expired topup slip images after the 30-day retention window.');

Schedule::command('lottery-images:backgrounds:prune --days=40 --limit=100')
    ->daily()
    ->withoutOverlapping()
    ->description('Delete lottery background asset sets after the 40-day draw retention window.');

Schedule::command('lottery-images:recover-stale-zip-imports --limit=25')
    ->everyFiveMinutes()
    ->withoutOverlapping()
    ->description('Recover stale lottery background zip imports that lost their worker heartbeat.');

Schedule::command('customer-notifications:recover-deliveries --limit=100')
    ->everyMinute()
    ->withoutOverlapping()
    ->description('Redispatch customer push deliveries missed by the queue or abandoned by a worker.');

Schedule::command('customer-communications:publish-due --limit=25')
    ->everyMinute()
    ->withoutOverlapping()
    ->onOneServer()
    ->description('Publish scheduled customer public-relations campaigns when they become due.');

Schedule::command('customer-accounts:process-deletions --limit=100')
    ->everyMinute()
    ->withoutOverlapping()
    ->onOneServer()
    ->description('Remind and automatically close customer accounts after their deletion grace period.');

Schedule::command('platform:alerts:check --dry-run --format=json')
    ->everyFiveMinutes()
    ->withoutOverlapping()
    ->description('Evaluate M10 alert policies in non-mutating dry-run mode.');
