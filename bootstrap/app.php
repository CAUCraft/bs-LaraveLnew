<?php

use App\Http\Middleware;
use Illuminate\Foundation\Application;
use Illuminate\Foundation\Configuration\Middleware as MiddlewareConfigurator;

/*
|--------------------------------------------------------------------------
| Create The Application
|--------------------------------------------------------------------------
|
| Laravel 11+ 风格的引导文件。路由仍由 App\Providers\RouteServiceProvider
| 统一注册（web / api / static），以保持 Blessing Skin 原有的路由行为。
|
*/

return Application::configure(basePath: dirname(__DIR__))
    ->withRouting(
        commands: __DIR__.'/../routes/console.php',
    )
    ->withExceptions()
    ->withMiddleware(function (MiddlewareConfigurator $middleware): void {
        /*
         * 全局中间件：用 Blessing Skin 的实现替换框架默认的
         * ConvertEmptyStringsToNull，并在末尾追加语言探测。
         */
        $middleware->replace(
            \Illuminate\Foundation\Http\Middleware\ConvertEmptyStringsToNull::class,
            Middleware\ConvertEmptyStringsToNull::class
        );

        $middleware->append(Middleware\DetectLanguagePrefer::class);

        /*
         * 路由中间件组：与升级前的 App\Http\Kernel 保持一致。
         */
        $middleware->group('web', [
            \Illuminate\Cookie\Middleware\EncryptCookies::class,
            \Illuminate\Cookie\Middleware\AddQueuedCookiesToResponse::class,
            \Illuminate\Session\Middleware\StartSession::class,
            \Illuminate\View\Middleware\ShareErrorsFromSession::class,
            \Illuminate\Foundation\Http\Middleware\PreventRequestForgery::class,
            Middleware\EnforceEverGreen::class,
            Middleware\RedirectToSetup::class,
            \Illuminate\Routing\Middleware\SubstituteBindings::class,
        ]);

        $middleware->group('api', [
            \Illuminate\Routing\Middleware\SubstituteBindings::class,
        ]);

        $middleware->group('authorize', [
            'auth:web',
            Middleware\RejectBannedUser::class,
            Middleware\EnsureEmailFilled::class,
            Middleware\FireUserAuthenticated::class,
        ]);

        /*
         * 中间件别名。
         */
        $middleware->alias([
            'auth' => Middleware\Authenticate::class,
            'cache.headers' => \Illuminate\Http\Middleware\SetCacheHeaders::class,
            'guest' => Middleware\RedirectIfAuthenticated::class,
            'role' => Middleware\CheckRole::class,
            'setup' => Middleware\CheckInstallation::class,
            'throttle' => \Illuminate\Routing\Middleware\ThrottleRequests::class,
            'verified' => Middleware\CheckUserVerified::class,
            'scope' => \Laravel\Passport\Http\Middleware\CheckTokenForAnyScope::class,
            'scopes' => \Laravel\Passport\Http\Middleware\CheckToken::class,
        ]);
    })
    ->create();
