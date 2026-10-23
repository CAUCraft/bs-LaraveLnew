# Blessing Skin → Laravel 13 升级说明

本文件记录了本次「把项目接入最新 Laravel 框架」所做的改动，以及本机运行环境的
启动 / 维护方式。所有操作均在本机完成，未向任何远端仓库推送。

## 一、当前运行环境

| 项目              | 版本 / 值                                                         |
| ----------------- | ----------------------------------------------------------------- |
| Laravel Framework | 13.38.0                                                           |
| PHP               | 8.4.27（CLI：`php8.4`，FPM：`php8.4-fpm`）                        |
| 数据库            | MySQL 8.0.46，库名 `blessingskin`                                 |
| Web 服务器        | Nginx 1.18（站点配置 `/etc/nginx/sites-available/blessing-skin`） |
| 进程用户          | PHP-FPM 以 `ctyun` 身份运行（`/etc/php/8.4/fpm/pool.d/www.conf`） |
| 站点地址          | http://localhost                                                  |
| 项目目录          | `/home/ctyun/blessing-skin-server-dev`                            |

数据库账号（写在 `.env` 中）：

- 库：`blessingskin`
- 用户：`bsuser`
- 密码：`BsSkin@2026`

后台管理员（首次安装时创建）：

- 账号：`admin@blessingskin.local`
- 密码：`Admin@123456`
- 昵称：管理员

> 建议登录后尽快修改管理员密码，并修改数据库密码（改完记得同步 `.env`）。

## 二、服务管理

```bash
sudo service nginx restart          # 重载/重启 Nginx
sudo service php8.4-fpm restart     # 重启 PHP-FPM
sudo service mysql restart          # 重启 MySQL
```

Nginx 与 PHP-FPM、MySQL 均已 `enable`，开机自启。

日志位置：

- Nginx：`/var/log/nginx/blessing-skin.{access,error}.log`
- 应用：`/home/ctyun/blessing-skin-server-dev/storage/logs/`

## 三、依赖与结构变化

### 1. 依赖升级

| 包                            | 升级前      | 升级后         |
| ----------------------------- | ----------- | -------------- |
| laravel/framework             | ^10.0       | ^13.0          |
| laravel/passport              | ^11.0       | ^13.10         |
| nesbot/carbon                 | ^2.0        | ^3.8           |
| symfony/yaml、symfony/process | ^5 / ^6     | ^7.4           |
| rcrowe/twigbridge、twig/twig  | 0.14 / ^3.0 | 0.14.8 / ^3.21 |
| spatie/laravel-ignition       | ^2.0        | ^2.12          |
| barryvdh/laravel-debugbar     | ^3.5        | ^4.4           |
| laravel/tinker                | ^2.4        | ^3.0           |
| phpunit/phpunit               | ^10.0       | ^13.0          |
| gregwar/captcha               | 1.\*        | ^2.1           |

已移除 `doctrine/dbal`（Laravel 11+ 原生支持 `change()` / `renameColumn()`）。

### 2. 本地化（patch）的第三方包

以下包自身声明的框架版本上限较低，已复制到 `packages/` 并通过 composer
`path` 仓库引用，仅放宽了版本约束，未修改业务代码：

- `packages/blessing-filter`（blessing/filter 1.5.0）
- `packages/blessing-rejection`（blessing/rejection 1.5.0）
- `packages/laravel-search-string`（lorisleiva/laravel-search-string 1.4.0）

### 3. 目录结构（Laravel 11+ 新骨架）

- `bootstrap/app.php`：改为 `Application::configure()` 形式，集中注册中间件
  （全局中间件、`web` / `api` / `authorize` 组、别名）。
- 新增 `bootstrap/providers.php`：服务提供者在此注册。
- 新增 `routes/console.php`。
- 删除 `app/Http/Kernel.php`、`app/Console/Kernel.php`、`server.php`。
- `public/index.php` 改为 `$app->handleRequest(Request::capture())`。
- `config/app.php` 不再维护 `providers` / `aliases`；`Option` 门面别名改在
  `AppServiceProvider` 中注册。
- `App\Exceptions\Handler` 保留，并在 `AppServiceProvider` 中绑定到容器。

### 4. 代码兼容性改动

- **Passport 13**：
  - 迁移文件改为发布到 `database/migrations`（`artisan vendor:publish --tag=passport-migrations`）。
  - `CheckForAnyScope` / `CheckScopes` 改名为 `CheckTokenForAnyScope` / `CheckToken`。
  - 旧的 JSON API 路由默认关闭，且返回结构变化（`redirect_uris`、`secret` 只存哈希、
    `id` 变为 UUID）。新增 `App\Http\Controllers\OAuthClientController`，
    在 `/oauth/clients` 上还原旧的数据结构，前端无需改动。
- **intervention/image 冲突**：Laravel 13 内置了基于 intervention/image v4 的
  `image` 容器绑定，会覆盖本项目依赖的 intervention/image v2。已在
  `AppServiceProvider` 中重新绑定，并在路由中改用分组属性传递控制器命名空间
  （`Router::namespace()` 已移除）。
- **前端资源**：已用 `yarn build` 生成 `public/app/*` 与 `resources/views/assets/*.twig`。

## 四、已知差异 / 注意事项

1. OAuth 应用的 **Secret** 在 Passport 13 中只保存哈希，因此列表页不再显示明文，
   仅在「创建成功」的响应里返回一次（与旧版行为不同，属安全改进）。
2. 升级后 `APP_ENV=production`、`APP_DEBUG=false`，报错页面不显示堆栈。
   排障时可临时改为 `local` + `true`，改完执行 `php artisan config:clear`。
3. 本项目未初始化远端 Git 仓库，仅在本地建立了基线提交，便于回滚：
   `git log` 可看到 `baseline Laravel 10 project before upgrade`。
4. Dockerfile 已同步到 `php:8.4-apache` 并补装 `imagick`、`intl`，
   但本机未安装 Docker，未实际构建验证。

## 五、插件兼容性修复（oauth 插件）

启用 `oauth` 插件后整站 500，报错为：

```
require(.../plugins/oauth/vendor/composer/../symfony/polyfill-php72/bootstrap.php): Failed to open stream
Declaration of Illuminate\Http\Response::setContent($content) must be compatible with
Symfony\Component\HttpFoundation\Response::setContent(?string $content): static
```

原因：该插件自带一整套 `vendor/`（Laravel 8 + Symfony 5），`PluginManager::loadVendor()`
在启动时 require 它，插件的自动加载器排在前面，把主程序的
`Illuminate\Http\Response` 换成了 L8 版本，与 Laravel 13 依赖的 Symfony 7.4 签名冲突，
且夹带了一个缺失文件的 polyfill，直接触发致命错误。

处理（只改插件，不动主程序）：

1. 在 `plugins/oauth/composer.json` 中声明只依赖 `laravel/socialite ^5.31` 与
   `socialiteproviders/manager ^4.10`（这两个版本支持 Laravel 13）。
2. 用 `replace` 把 Illuminate / Guzzle / PSR / Symfony polyfill 等主程序已有的包
   标记为“由宿主提供”，Composer 因此不会在插件里重复安装它们。
3. 重新 `composer install`，插件的 `vendor/` 现在只剩
   `laravel/socialite`、`socialiteproviders/manager`、`league/oauth1-client`、
   `firebase/php-jwt`、`phpseclib` 及其独有依赖。

结果：插件与主程序共用同一套框架类，`/auth/login/{driver}` 路由正常注册。
未配置第三方平台时访问会提示缺少 `client_id` 等配置项（属预期，配置后即可跳转）。

> 注意：`plugins/` 被 `.gitignore` 忽略，以上为运行时修复。若以后重新下载该插件，
> 其自带 `vendor/` 会再次覆盖，需要按同样方式重建（保留 `plugins/oauth/composer.json`
> 后执行 `composer install` 即可）。

## 六、版本号

`config/app.php` 的 `version` 已改为 `6.0.2-R`。由于 `-R` 不是 Composer 认可的
版本前缀，`Composer\Semver` 解析时会抛 `UnexpectedValueException`，而
`RedirectToSetup` 中间件每次请求都会比较版本，会导致整站 500。

因此在 `app/helpers.php` 增加了 `normalize_version()`（把 `6.0.2-R` 规整为 `6.0.2`
后再比较），并应用于四处版本比较：`RedirectToSetup`、`UpdateController`、
`UpdateCommand`、`PluginManager::getUnsatisfied`。界面上仍显示 `6.0.2-R`。

## 七、常用命令

```bash
cd /home/ctyun/blessing-skin-server-dev

php8.4 artisan about              # 环境总览
php8.4 artisan route:list         # 路由列表
php8.4 artisan migrate            # 数据库迁移
php8.4 artisan bs:install <email> <password> <nickname>   # 全新安装
php8.4 vendor/bin/phpunit         # 运行测试（228 个用例）
```

测试结果：`OK (228 tests, 1766 assertions)`。
