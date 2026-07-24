<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;

class SupportFaq extends Model
{
    protected $table = 'support_faqs';
    public $incrementing = false;
    protected $keyType = 'string';
    protected $guarded = [];
    protected $casts = [
        'question_json' => 'array',
        'answer_json' => 'array',
        'keywords_json' => 'array',
        'published_at' => 'datetime',
    ];
}
