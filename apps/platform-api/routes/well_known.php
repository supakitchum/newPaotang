<?php

use App\Modules\Auth\Http\Controllers\CustomerPasskeyAssociationController;
use Illuminate\Support\Facades\Route;

Route::get('/.well-known/apple-app-site-association', [
    CustomerPasskeyAssociationController::class,
    'apple',
]);
Route::get('/.well-known/assetlinks.json', [
    CustomerPasskeyAssociationController::class,
    'android',
]);
