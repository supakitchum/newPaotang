<?php

namespace App\Models;

class StockPartnerDistribution extends BaseModel
{
    protected $table = 'stock_partner_distributions';

    protected $fillable = [
        'id',
        'game_id',
        'partner_id',
        'tenant_id',
        'percent_basis_points',
        'status',
        'created_at',
        'updated_at',
    ];

    protected $casts = [
        'percent_basis_points' => 'integer',
    ];
}
