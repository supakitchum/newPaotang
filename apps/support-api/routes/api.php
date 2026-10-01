<?php

use App\Http\Controllers\AdminSupportController;
use App\Http\Controllers\CustomerSupportController;
use App\Http\Controllers\SupportAttachmentController;
use App\Http\Controllers\SupportRealtimeController;
use Illuminate\Support\Facades\Route;

Route::get('/attachments/{attachment}', [SupportAttachmentController::class, 'show'])
    ->middleware('signed')
    ->name('support.attachment');

Route::middleware('support.auth:customer')->prefix('customer')->group(function (): void {
    Route::get('/bootstrap', [CustomerSupportController::class, 'bootstrap']);
    Route::get('/faqs', [CustomerSupportController::class, 'faqs']);
    Route::post('/faqs/{faq}/feedback', [CustomerSupportController::class, 'faqFeedback']);
    Route::get('/unread-count', [CustomerSupportController::class, 'unreadCount']);
    Route::get('/tickets', [CustomerSupportController::class, 'index']);
    Route::post('/tickets', [CustomerSupportController::class, 'store']);
    Route::get('/tickets/{ticket}', [CustomerSupportController::class, 'show']);
    Route::get('/tickets/{ticket}/messages', [CustomerSupportController::class, 'messages']);
    Route::post('/tickets/{ticket}/messages', [CustomerSupportController::class, 'sendMessage']);
    Route::post('/tickets/{ticket}/read', [CustomerSupportController::class, 'markRead']);
    Route::post('/tickets/{ticket}/close', [CustomerSupportController::class, 'close']);
    Route::post('/tickets/{ticket}/rating', [CustomerSupportController::class, 'rate']);
    Route::post('/realtime/auth', [SupportRealtimeController::class, 'authorize']);
});

Route::middleware('support.auth:admin')->prefix('admin')->group(function (): void {
    Route::get('/bootstrap', [AdminSupportController::class, 'bootstrap']);
    Route::get('/tickets', [AdminSupportController::class, 'index']);
    Route::get('/tickets/{ticket}', [AdminSupportController::class, 'show']);
    Route::get('/tickets/{ticket}/messages', [AdminSupportController::class, 'messages']);
    Route::post('/tickets/{ticket}/messages', [AdminSupportController::class, 'sendMessage']);
    Route::post('/tickets/{ticket}/read', [AdminSupportController::class, 'markRead']);
    Route::post('/tickets/{ticket}/waiting-customer', [AdminSupportController::class, 'waitingCustomer']);
    Route::post('/tickets/{ticket}/close', [AdminSupportController::class, 'close']);
    Route::post('/tickets/{ticket}/assign', [AdminSupportController::class, 'assign']);
    Route::put('/agent-state', [AdminSupportController::class, 'agentState']);
    Route::post('/agent-state/heartbeat', [AdminSupportController::class, 'heartbeat']);
    Route::get('/agents', [AdminSupportController::class, 'agents']);
    Route::put('/agents/{agent}/state', [AdminSupportController::class, 'updateAgentState']);
    Route::get('/categories', [AdminSupportController::class, 'categories']);
    Route::post('/categories', [AdminSupportController::class, 'saveCategory']);
    Route::put('/categories/{category}', [AdminSupportController::class, 'saveCategory']);
    Route::get('/faqs', [AdminSupportController::class, 'faqs']);
    Route::post('/faqs', [AdminSupportController::class, 'saveFaq']);
    Route::put('/faqs/{faq}', [AdminSupportController::class, 'saveFaq']);
    Route::get('/settings', [AdminSupportController::class, 'settings']);
    Route::put('/settings', [AdminSupportController::class, 'updateSettings']);
    Route::get('/reports', [AdminSupportController::class, 'reports']);
    Route::post('/realtime/auth', [SupportRealtimeController::class, 'authorize']);
});
