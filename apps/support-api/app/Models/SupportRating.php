<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;

class SupportRating extends Model
{
    protected $table = 'support_ratings';
    public $incrementing = false;
    protected $keyType = 'string';
    protected $guarded = [];
}
