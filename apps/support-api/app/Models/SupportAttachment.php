<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;

class SupportAttachment extends Model
{
    protected $table = 'support_attachments';
    public $incrementing = false;
    protected $keyType = 'string';
    protected $guarded = [];
}
