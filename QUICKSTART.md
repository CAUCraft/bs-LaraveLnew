# Blessing Skin 6.0.2-R 发布包（开箱即用）

本包基于 Blessing Skin 6.0.2，已升级到 **Laravel 13.38.0 / PHP 8.4**，并内置了
**SQLite 演示数据库**、已构建的前端资源、已安装的 Composer 依赖，解压后无需
`composer install`、无需 `yarn build`，直接起服务即可访问。

## 一、演示账号

| 项目 | 值 |
| --- | --- |
| 站点地址 | http://localhost |
| 管理员邮箱 | `demo@blessingskin.local` |
| 管理员密码 | `Demo@123456` |
| 数据库 | SQLite，文件 `database/database.sqlite` |

> 上线前请务必在「个人中心 → 修改密码」中改掉演示密码，并在后台「站点设置」里
> 把站点地址改成实际域名。

## 二、环境要求

- PHP **8.3 及以上**（推荐 8.4），需要扩展：
  `gd`、`imagick`、`zip`、`pdo_sqlite`（或 `pdo_mysql`）、`mbstring`、`curl`、
  `dom`、`fileinfo`、`json`、`openssl`、`tokenizer`、`xml`、`ctype`
- Web 服务器：Nginx / Apache / Caddy 任一，或先用 PHP 内置服务器体验
- **不需要** Composer、Node.js

## 三、立即体验（PHP 内置服务器）

```bash
cd blessing-skin-server-6.0.2-R
php -S 127.0.0.1:8000 -t public
```

浏览器打开 <http://127.0.0.1:8000>，用上面的演示账号登录。
（内置服务器仅供本地体验，正式部署请用 Nginx / Apache。）

## 四、正式部署（Nginx + PHP-FPM）

```nginx
server {
    listen 80;
    server_name skin.example.com;
    root /path/to/blessing-skin-server-6.0.2-R/public;
    index index.php;

    location / {
        try_files $uri $uri/ /index.php?$query_string;
    }

    location ~ \.php$ {
        include fastcgi_params;
        fastcgi_pass unix:/run/php/php8.4-fpm.sock;
        fastcgi_param SCRIPT_FILENAME $document_root$fastcgi_script_name;
    }

    location ~ /\.(?!well-known).* { deny all; }
}
```

注意 `root` 要指向 **public** 子目录，不能指向项目根目录。

目录权限（PHP 运行用户需可写）：

```bash
chown -R www-data:www-data storage bootstrap/cache
chmod -R ug+rwX storage bootstrap/cache
```

## 五、切换到 MySQL（生产建议）

1. 建库：

```sql
CREATE DATABASE blessingskin CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
CREATE USER 'bsuser'@'localhost' IDENTIFIED BY '你的密码';
GRANT ALL PRIVILEGES ON blessingskin.* TO 'bsuser'@'localhost';
FLUSH PRIVILEGES;
```

2. 修改 `.env`：

```dotenv
DB_CONNECTION=mysql
DB_HOST=127.0.0.1
DB_PORT=3306
DB_DATABASE=blessingskin
DB_USERNAME=bsuser
DB_PASSWORD=你的密码
```

3. 重新初始化（会清空演示数据）：

```bash
rm -f storage/install.lock
php artisan bs:install 你的邮箱 '你的密码' '你的昵称'
php artisan config:clear
```

`bs:install` 会自动建表、生成 `APP_KEY` 与 Passport 密钥、创建超级管理员。

## 六、已内置的插件

`plugins/` 下已附带，可在后台「插件管理」里直接启用：

| 插件 | 版本 | 说明 |
| --- | --- | --- |
| oauth | 1.0.7 | 第三方登录（GitHub / Google / Microsoft / Steam 等），已修正在 Laravel 13 下的致命错误 |
| yggdrasil-connect | 6.2.0 | 外置登录（Yggdrasil API） |
| disable-registration | 1.0.3 | 关闭注册入口 |
| hide-advanced-menu | 1.0.1 | 隐藏侧栏「高级功能」 |
| pray-for-kyoto-animation | 1.0.3 | 祈福京阿尼主题 |

OAuth 插件需要自行在 `config/services.php` 中填入各平台凭据后才会生效。

## 七、常见问题

- **页面 500**：查看 `storage/logs/laravel-*.log`；确认 `storage`、`bootstrap/cache` 可写。
- **样式错乱 / 图片不显示**：确认 `root` 指向 `public/`，且 `public/app` 目录完整。
- **忘记密码**：项目根执行
  `php artisan tinker` 后手动改库，或重新 `bs:install`（会重建数据库）。
- **修改 `.env` 不生效**：执行 `php artisan config:clear`。

## 八、版本信息

- Blessing Skin：**6.0.2-R**
- Laravel Framework：13.38.0
- PHP：8.3+（开发与验证环境 8.4.27）
- 前端资源：已构建，位于 `public/app` 与 `resources/views/assets`

## 九、目录说明（客户无需关心）

| 目录 | 用途 |
| --- | --- |
| `vendor/` | Composer 依赖，已随包提供 |
| `packages/` | 三个本地化（放宽版本约束）的第三方包 |
| `plugins/` | 插件目录，可后台上传 zip 安装 |
| `storage/` | 日志、缓存、上传的材质，需可写 |
| `public/` | Web 根目录 |

如需二次开发前端，另行安装 Node.js 后执行 `yarn install && yarn build` 即可。
