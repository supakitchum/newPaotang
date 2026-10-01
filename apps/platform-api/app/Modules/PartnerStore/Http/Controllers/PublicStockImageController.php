<?php

namespace App\Modules\PartnerStore\Http\Controllers;

use App\Modules\PartnerStore\Services\VirtualLotteryImageService;
use Illuminate\Http\Response;
use Illuminate\Routing\Controller;

class PublicStockImageController extends Controller
{
    public function __construct(private readonly VirtualLotteryImageService $images)
    {
    }

    public function show(string $token): Response
    {
        $result = $this->images->renderPublicImage($token);

        return response(
            $result['bytes'] ?? '',
            (int) ($result['status'] ?? 404),
            $result['headers'] ?? ['Cache-Control' => 'no-store'],
        );
    }
}
