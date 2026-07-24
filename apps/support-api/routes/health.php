<?php

use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Route;

Route::get('/health/live', fn () => response()->json(['status' => 'ok']));
Route::get('/health/ready', function () {
    DB::select('select 1');
    return response()->json(['status' => 'ready', 'database' => config('database.connections.pgsql.database')]);
});
