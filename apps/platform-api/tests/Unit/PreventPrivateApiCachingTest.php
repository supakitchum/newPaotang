<?php

namespace Tests\Unit;

use App\Shared\Http\Middleware\PreventPrivateApiCaching;
use Illuminate\Http\Request;
use PHPUnit\Framework\TestCase;
use Symfony\Component\HttpFoundation\Response;

class PreventPrivateApiCachingTest extends TestCase
{
    public function test_customer_responses_including_errors_are_never_stored(): void
    {
        foreach ([200, 401, 422, 500] as $status) {
            $response = (new PreventPrivateApiCaching)->handle(
                Request::create('/api/v1/customer/activities'),
                fn () => new Response('{}', $status, ['Cache-Control' => 'public, max-age=600']),
            );
            $this->assertTrue($response->headers->hasCacheControlDirective('no-store'));
            $this->assertTrue($response->headers->hasCacheControlDirective('private'));
        }
    }

    public function test_authenticated_public_response_is_not_shared(): void
    {
        $request = Request::create('/api/v1/public/activities');
        $request->headers->set('Authorization', 'Bearer test-token');
        $response = (new PreventPrivateApiCaching)->handle($request, fn () => new Response('{}'));
        $this->assertTrue($response->headers->hasCacheControlDirective('no-store'));
    }

    public function test_anonymous_images_keep_immutable_caching(): void
    {
        $response = (new PreventPrivateApiCaching)->handle(
            Request::create('/api/v1/public/assets/tenants/example/activities/image.webp'),
            fn () => new Response('image', 200, ['Cache-Control' => 'public, max-age=31536000, immutable']),
        );
        $this->assertTrue($response->headers->hasCacheControlDirective('immutable'));
        $this->assertFalse($response->headers->hasCacheControlDirective('no-store'));
    }
}
