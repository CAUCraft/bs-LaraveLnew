<?php

namespace App\Providers;

use App\Models\Scope;
use Illuminate\Foundation\Support\Providers\AuthServiceProvider as ServiceProvider;
use Illuminate\Support\Facades\Cache;
use Illuminate\Support\Facades\Storage;
use Laravel\Passport\Passport;

class AuthServiceProvider extends ServiceProvider
{
    /**
     * The model to policy mappings for the application.
     *
     * @var array<class-string, class-string>
     */
    protected $policies = [
    ];

    public function register(): void
    {
        /*
         * Passport 13 的 JSON API 路由（/oauth/clients 等）返回的是新结构，
         * 且默认关闭。Blessing Skin 改为在 RouteServiceProvider 中注册
         * 兼容旧版数据结构的接口（见 OAuthClientController），
         * 因此这里保持 Passport 自带的 JSON API 路由关闭。
         */
        Passport::$registersJsonApiRoutes = false;
    }

    /**
     * Register any authentication / authorization services.
     */
    public function boot(): void
    {
        $defaultScopes = [
            'User.Read' => 'auth.oauth.scope.user.read',
            'Notification.Read' => 'auth.oauth.scope.notification.read',
            'Notification.ReadWrite' => 'auth.oauth.scope.notification.readwrite',
            'Player.Read' => 'auth.oauth.scope.player.read',
            'Player.ReadWrite' => 'auth.oauth.scope.player.readwrite',
            'Closet.Read' => 'auth.oauth.scope.closet.read',
            'Closet.ReadWrtie' => 'auth.oauth.scope.closet.readwrite',
            'UsersManagement.Read' => 'auth.oauth.scope.users-management.read',
            'UsersManagement.ReadWrite' => 'auth.oauth.scope.users-management.readwrite',
            'PlayersManagement.Read' => 'auth.oauth.scope.players-management.read',
            'PlayersManagement.ReadWrite' => 'auth.oauth.scope.players-management.readwrite',
            'ClosetManagement.Read' => 'auth.oauth.scope.closet-management.read',
            'ClosetManagement.ReadWrite' => 'auth.oauth.scope.closet-management.readwrite',
            'ReportsManagement.Read' => 'auth.oauth.scope.reports-management.read',
            'ReportsManagement.ReadWrite' => 'auth.oauth.scope.reports-management.readwrite',
        ];

        /*
         * Return empty scopes if running unit tests or before installation.
         * In these cases, migrations aren’t run yet, so DB queries will fail.
         * OAuth isn’t tested in unit tests, so returning empty scopes should be fine...?
         * Maybe the best approach is to run migrations before bootstrap in tests,
         * but this seems impossible for DB_DATABASE=:memory:;
         * Or change how scopes are registered so they don't depend on the database,
         * but that may introduce BREAKING CHANGES and plugin incompatibility.
         * PRs welcome for better solutions!
         */
        $scopes = (app()->runningUnitTests() || !Storage::disk('root')->exists('storage/install.lock')) ? [] : Cache::rememberForever('scopes', function () {
            return Scope::pluck('description', 'name')->toArray();
        });

        Passport::tokensCan(array_merge($defaultScopes, $scopes));

        Passport::setDefaultScope(['User.Read']);
    }
}
