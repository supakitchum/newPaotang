<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;

class SupportActor extends Model
{
    protected $table = 'support_actors';
    public $incrementing = false;
    protected $keyType = 'string';
    protected $guarded = [];
    protected $casts = ['permissions_json' => 'array', 'last_authenticated_at' => 'datetime'];
}
