<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;

class SupportTenant extends Model
{
    protected $table = 'support_tenants';
    public $incrementing = false;
    protected $keyType = 'string';
    protected $guarded = [];
}
