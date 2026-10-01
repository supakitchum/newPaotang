<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;

abstract class BasePivotModel extends Model
{
    public $incrementing = false;

    protected $primaryKey = null;

    protected $keyType = 'string';

    protected $fillable = [];
}
