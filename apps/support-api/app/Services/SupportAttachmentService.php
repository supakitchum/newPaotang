<?php

namespace App\Services;

use App\Models\SupportAttachment;
use App\Models\SupportMessage;
use App\Models\SupportTicket;
use Illuminate\Http\UploadedFile;
use Illuminate\Support\Facades\Storage;
use Illuminate\Support\Facades\URL;
use Illuminate\Support\Str;
use RuntimeException;

class SupportAttachmentService
{
    /**
     * @param array<int, UploadedFile> $files
     * @return array<int, SupportAttachment>
     */
    public function store(SupportTicket $ticket, SupportMessage $message, array $files, int $maxFiles, int $maxBytes): array
    {
        if (count($files) > $maxFiles) {
            throw new RuntimeException('Too many support message attachments.');
        }

        $stored = [];
        foreach ($files as $file) {
            if (! $file->isValid() || $file->getSize() <= 0 || $file->getSize() > $maxBytes) {
                throw new RuntimeException('A support attachment is invalid or too large.');
            }

            $bytes = file_get_contents($file->getRealPath());
            $source = is_string($bytes) ? @imagecreatefromstring($bytes) : false;
            if ($source === false) {
                throw new RuntimeException('Support attachments must be valid images.');
            }

            $width = imagesx($source);
            $height = imagesy($source);
            ob_start();
            imagewebp($source, null, 86);
            $normalized = ob_get_clean();
            imagedestroy($source);
            if (! is_string($normalized) || $normalized === '') {
                throw new RuntimeException('Unable to normalize support attachment.');
            }

            $id = 'sat_'.Str::ulid()->toBase32();
            $disk = (string) config('support.attachments.disk', 'local');
            $path = sprintf(
                'support/%s/%s/%s/%s.webp',
                $ticket->tenant_id,
                $ticket->id,
                $message->id,
                $id,
            );
            Storage::disk($disk)->put($path, $normalized, ['visibility' => 'private']);

            $stored[] = SupportAttachment::query()->create([
                'id' => $id,
                'tenant_id' => $ticket->tenant_id,
                'ticket_id' => $ticket->id,
                'message_id' => $message->id,
                'disk' => $disk,
                'storage_path' => $path,
                'mime_type' => 'image/webp',
                'byte_size' => strlen($normalized),
                'checksum_sha256' => hash('sha256', $normalized),
                'width' => $width,
                'height' => $height,
                'original_name' => Str::limit($file->getClientOriginalName(), 255, ''),
            ]);
        }

        return $stored;
    }

    public function temporaryUrl(SupportAttachment $attachment): string
    {
        $disk = Storage::disk((string) $attachment->disk);
        if (method_exists($disk, 'temporaryUrl') && (string) $attachment->disk !== 'local') {
            return $disk->temporaryUrl(
                (string) $attachment->storage_path,
                now()->addMinutes((int) config('support.attachments.signed_url_minutes', 10)),
            );
        }

        return URL::temporarySignedRoute(
            'support.attachment',
            now()->addMinutes((int) config('support.attachments.signed_url_minutes', 10)),
            ['attachment' => $attachment->id],
        );
    }
}
