<?php

namespace Tests\Unit;

use PHPUnit\Framework\TestCase;

class CustomerOpenApiContractTest extends TestCase
{
    private const HTTP_METHODS = ['get', 'post', 'put', 'patch', 'delete', 'options', 'head', 'trace'];

    public function test_customer_and_public_routes_are_documented_without_duplicate_methods(): void
    {
        $platformApiRoot = dirname(__DIR__, 2);
        $openApiPath = getenv('OPENAPI_PATH') ?: dirname($platformApiRoot, 2).'/docs/openapi.yaml';
        $routePath = $platformApiRoot.'/routes/api.php';

        $this->assertFileExists($routePath);
        $this->assertFileExists($openApiPath);

        $routeSource = file_get_contents($routePath);
        $openApiSource = file_get_contents($openApiPath);

        $this->assertIsString($routeSource);
        $this->assertIsString($openApiSource);

        [$documentedRoutes, $duplicates] = $this->documentedRoutes($openApiSource);

        $this->assertSame([], $duplicates, 'Duplicate OpenAPI path method keys: '.implode(', ', $duplicates));

        $customerRoutes = $this->customerRoutes($routeSource);
        $this->assertGreaterThanOrEqual(50, count($customerRoutes), 'Customer/public route parser returned an unexpectedly small route set.');

        $missing = [];
        foreach ($customerRoutes as [$method, $path]) {
            if ($this->isDeferredNativeSecurityRoute($path)) {
                continue;
            }

            if (! isset($documentedRoutes[$path][$method])) {
                $missing[] = strtoupper($method).' '.$path;
            }
        }

        sort($missing);

        $this->assertSame([], $missing, 'Customer/public routes missing from OpenAPI: '.implode(', ', $missing));
    }

    /**
     * @return array{0: array<string, array<string, true>>, 1: list<string>}
     */
    private function documentedRoutes(string $source): array
    {
        $routes = [];
        $duplicates = [];
        $currentPath = null;

        foreach (preg_split('/\R/', $source) ?: [] as $line) {
            if (preg_match('/^  (\/[^:]+):\s*$/', $line, $matches) === 1) {
                $currentPath = $matches[1];
                $routes[$currentPath] ??= [];

                continue;
            }

            if ($currentPath === null || preg_match('/^    (get|post|put|patch|delete|options|head|trace):\s*$/', $line, $matches) !== 1) {
                continue;
            }

            $method = $matches[1];
            if (isset($routes[$currentPath][$method])) {
                $duplicates[] = strtoupper($method).' '.$currentPath;
            }

            $routes[$currentPath][$method] = true;
        }

        return [$routes, $duplicates];
    }

    /**
     * @return list<array{0: string, 1: string}>
     */
    private function customerRoutes(string $source): array
    {
        $routes = [];
        $methodPattern = implode('|', self::HTTP_METHODS);

        preg_match_all(
            "/Route::($methodPattern)\\(\\s*'((?:\\/public|\\/customer)[^']*)'/",
            $source,
            $singleMethodMatches,
            PREG_SET_ORDER,
        );

        foreach ($singleMethodMatches as $match) {
            $routes[] = [strtolower($match[1]), $match[2]];
        }

        preg_match_all(
            "/Route::match\\(\\s*\\[([^]]+)]\\s*,\\s*'((?:\\/public|\\/customer)[^']*)'/",
            $source,
            $multiMethodMatches,
            PREG_SET_ORDER,
        );

        foreach ($multiMethodMatches as $match) {
            preg_match_all("/'($methodPattern)'/", $match[1], $methods);
            foreach ($methods[1] as $method) {
                $routes[] = [strtolower($method), $match[2]];
            }
        }

        return $routes;
    }

    private function isDeferredNativeSecurityRoute(string $path): bool
    {
        return str_starts_with($path, '/customer/auth/biometric/')
            || $path === '/customer/auth/security-events';
    }
}
