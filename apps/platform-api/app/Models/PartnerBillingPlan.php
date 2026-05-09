<?php

namespace App\Models;

class PartnerBillingPlan extends BaseModel
{
    protected $table = 'partner_billing_plans';

    protected $fillable = [
        'id',
        'code',
        'name',
        'status',
        'monthly_fee_amount',
        'currency',
        'features_json',
        'limits_json',
        'created_at',
        'updated_at',
    ];

    protected $casts = [
        'monthly_fee_amount' => 'integer',
        'features_json' => 'array',
        'limits_json' => 'array',
    ];
}
