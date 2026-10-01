<?php

namespace App\Http\Controllers;

use App\Models\SupportAttachment;
use Illuminate\Routing\Controller;
use Illuminate\Support\Facades\Storage;
use Symfony\Component\HttpFoundation\StreamedResponse;

class SupportAttachmentController extends Controller
{
    public function show(SupportAttachment $attachment): StreamedResponse
    {
        return Storage::disk((string) $attachment->disk)->download(
            (string) $attachment->storage_path,
            (string) ($attachment->original_name ?: $attachment->id.'.webp'),
            [
                'Content-Type' => (string) $attachment->mime_type,
                'Cache-Control' => 'private, max-age=300',
                'X-Content-Type-Options' => 'nosniff',
            ],
        );
    }
}
