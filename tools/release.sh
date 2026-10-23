#!/usr/bin/env bash
#
# Blessing Skin Server —— 正式 release 打包脚本（Linux / 宝塔环境）
#
# 产出的安装包严格遵循"干净骨架"原则（参考上一版正式版安装包）：
#   1. 绝不包含 .env（里头有数据库密码、APP_KEY），但保留 .env.example
#      —— bootstrap/chkenv.php 首次访问时会用 .env.example 自动生成 .env；
#   2. storage/ 只保留空目录骨架（各目录仅留 .gitignore），不带任何
#      编译后的视图、缓存、session、日志、Passport 密钥、install.lock；
#   3. bootstrap/cache/ 只保留 .gitignore，不携带 packages.php / services.php
#      等生成物（Laravel 会按需重建）；
#   4. 不携带前端源码（resources/assets）、sourcemap、plugins 实装内容、
#      composer.lock、node_modules、dist、旧安装包等开发/运行时产物。
#
# 前置条件：前端资源已构建（public/app 存在且含 favicon.ico）。
#   首次构建请先执行：yarn install && bash tools/build-assets.sh
#   CI 中由 .github/workflows/release.yml 自动完成。
#
# 用法：
#   bash tools/release.sh              # 默认顺便用 composer --no-dev 精简 vendor
#   bash tools/release.sh --no-composer # 跳过 composer（无网络/无 composer 时）
#
# 输出：dist/blessing-skin-server-<版本号>.zip
#
set -euo pipefail

ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
cd "$ROOT"

WITH_COMPOSER=1
for arg in "$@"; do
    case "$arg" in
        --no-composer) WITH_COMPOSER=0 ;;
        -h|--help) sed -n '2,/^set -euo/p' "${BASH_SOURCE[0]}" | sed 's/^# \{0,1\}//' | sed '$d'; exit 0 ;;
        *) echo "未知参数：$arg" >&2; exit 1 ;;
    esac
done

VERSION=$(sed -nE "s/.*'version'[[:space:]]*=>[[:space:]]*'([^']+)'.*/\1/p" config/app.php | head -1)
if [ -z "$VERSION" ]; then
    echo "[错误] 无法从 config/app.php 读取版本号" >&2
    exit 1
fi

NAME="blessing-skin-server-$VERSION"
DIST="$ROOT/dist"
STAGE=$(mktemp -d /tmp/bs-release.XXXXXX)
PKG="$STAGE/$NAME"
trap '/bin/rm -rf "$STAGE"' EXIT

mkdir -p "$PKG" "$DIST"

# ---------------------------------------------------------------------------
# 工具函数：把 storage 重置为干净骨架
# ---------------------------------------------------------------------------
reset_storage() {
    local pkg=$1
    /bin/rm -rf "$pkg/storage"
    for d in app/public framework/cache/data framework/sessions framework/views logs packages debugbar textures; do
        mkdir -p "$pkg/storage/$d"
        printf '*\n!.gitignore\n' > "$pkg/storage/$d/.gitignore"
    done

    cat > "$pkg/storage/app/.gitignore" <<'EOF'
*
!public/
!.gitignore
EOF

    cat > "$pkg/storage/framework/.gitignore" <<'EOF'
config.php
routes.php
schedule-*
compiled.php
services.json
events.scanned.php
routes.scanned.php
down
testing/
EOF
}

# ---------------------------------------------------------------------------
# 工具函数：清空 bootstrap/cache（保留 .gitignore）
# ---------------------------------------------------------------------------
reset_bootstrap_cache() {
    local pkg=$1
    [ -d "$pkg/bootstrap/cache" ] || mkdir -p "$pkg/bootstrap/cache"
    find "$pkg/bootstrap/cache" -type f ! -name '.gitignore' -delete
    [ -f "$pkg/bootstrap/cache/.gitignore" ] || printf '*\n!.gitignore\n' > "$pkg/bootstrap/cache/.gitignore"
}

echo "==> 打包 $NAME"
echo "    源目录：$ROOT"
echo "    临时目录：$STAGE"

#
# 1. 白名单拷贝（只列出的内容才会进包，新增的开发文件不会意外混入）
#
ITEMS=(
    app artisan bootstrap config database routes
    public vendor plugins resources
    index.html LICENSE README.md README-zh.md QUICKSTART.md
    .env.example
    composer.json          # Laravel 13 的 Application::getNamespace() 会读取它，必须随包发布
)
for item in "${ITEMS[@]}"; do
    if [ ! -e "$ROOT/$item" ]; then
        echo "    [跳过] 不存在：$item"
        continue
    fi
    rsync -a --delete-excluded "$ROOT/$item" "$PKG/"
done

#
# 2. 剔除源码/开发专用内容
#
echo "==> 清理开发内容"
/bin/rm -rf "$PKG/resources/assets"                 # 前端 TS/TSX/样式源码，构建产物在 public/app
/bin/rm -f  "$PKG/.env"                             # 绝对不允许进包
find "$PKG" -type f -name '*.map' -delete           # sourcemap

# public/lang/*.js 是运行时按需生成的翻译缓存（Resources/Translations/JavaScript.php），
# 站点首次访问会自动重建，不应进包；但目录本身要保留（web 用户需可写）
if [ -d "$PKG/public/lang" ]; then
    find "$PKG/public/lang" -type f ! -name '.gitignore' -delete
else
    mkdir -p "$PKG/public/lang"
fi
[ -f "$PKG/public/lang/.gitignore" ] || printf '*\n!.gitignore\n' > "$PKG/public/lang/.gitignore"

if [ ! -d "$PKG/public/app" ] || [ -z "$(find "$PKG/public/app" -type f -print -quit)" ]; then
    echo "[错误] public/app 为空：前端资源未构建，请先执行 bash tools/build-assets.sh" >&2
    exit 1
fi
if [ ! -f "$PKG/public/app/favicon.ico" ]; then
    echo "[错误] public/app/favicon.ico 缺失：请执行 bash tools/build-assets.sh（它会补拷静态文件）" >&2
    exit 1
fi

# PLUGINS 与 public/plugins 清空（插件由用户在站点后台自行安装）
if [ -d "$PKG/plugins" ]; then
    find "$PKG/plugins" -mindepth 1 -maxdepth 1 ! -name '.gitignore' -exec /bin/rm -rf {} +
fi
if [ -d "$PKG/public/plugins" ]; then
    find "$PKG/public/plugins" -mindepth 1 -maxdepth 1 ! -name '.gitignore' -exec /bin/rm -rf {} +
else
    mkdir -p "$PKG/public/plugins"
    printf '*\n!.gitignore\n' > "$PKG/public/plugins/.gitignore"
fi

reset_bootstrap_cache "$PKG"

#
# 3. storage 重置为空骨架（关键：rsync 会把线上缓存、日志、密钥、install.lock 带进来）
#
echo "==> 重建 storage 空骨架"
reset_storage "$PKG"

#
# 4. 可选：剔除 composer 开发依赖，缩小 vendor
#
# 宝塔环境下 php 不在 PATH（/www/server/php 为 750 root），需要 root 并以绝对路径调用；
# 系统自带的 /usr/bin/composer 可能过旧（<2.2，读不了本项目的 lock），
# 因此优先使用项目内自带的 tools/composer.phar。
PHP_BIN=""
if php -v >/dev/null 2>&1; then
    PHP_BIN=$(command -v php)
elif [ -x /www/server/php/84/bin/php ]; then
    PHP_BIN=/www/server/php/84/bin/php
fi

COMPOSER_CMD=()
if [ -f "$ROOT/tools/composer.phar" ] && [ -n "$PHP_BIN" ]; then
    COMPOSER_CMD=("$PHP_BIN" "$ROOT/tools/composer.phar")
elif command -v composer >/dev/null 2>&1 && [ -n "$PHP_BIN" ]; then
    COMPOSER_CMD=("$PHP_BIN" "$(command -v composer)")
fi

if [ "$WITH_COMPOSER" = 1 ] && [ ${#COMPOSER_CMD[@]} -gt 0 ] && [ -f "$ROOT/composer.lock" ]; then
    echo "==> composer install --no-dev（剔除开发依赖，PHP: $PHP_BIN）"
    cp "$ROOT/composer.lock" "$PKG/composer.lock"   # 仅构建期临时使用
    if ( cd "$PKG" && COMPOSER_ALLOW_SUPERUSER=1 COMPOSER_NO_INTERACTION=1 \
            "${COMPOSER_CMD[@]}" install \
            --no-dev --prefer-dist --optimize-autoloader --no-interaction --no-progress >/dev/null 2>&1 ); then
        /bin/rm -rf "$PKG/vendor/bin"
        echo "    vendor 已精简"
    else
        echo "    [警告] composer 执行失败（常见原因：无网络），保留现有 vendor，包体积会偏大"
    fi
    /bin/rm -f "$PKG/composer.lock"
else
    echo "==> 跳过 composer（--no-composer / 未安装 composer / 无法调用 php CLI）"
    echo "    提示：宝塔环境请用 root 执行，脚本会使用 /www/server/php/84/bin/php 与 tools/composer.phar"
fi

#
# 5. 冒烟测试：确认包内 vendor / autoload 可用（会把 cache 写脏，之后要再清一次）
#
if [ -n "$PHP_BIN" ]; then
    echo "==> 冒烟测试：boot 应用"
    BOOT_OUT=$(cd "$PKG" && APP_RUNNING_IN_CONSOLE=1 "$PHP_BIN" artisan --version 2>&1 | tail -1 || true)
    if printf '%s' "$BOOT_OUT" | grep -q 'Laravel Framework'; then
        echo "    OK：$BOOT_OUT"
    else
        echo "    [警告] 冒烟测试未通过：$BOOT_OUT"
    fi
    reset_bootstrap_cache "$PKG"
    reset_storage "$PKG"
    /bin/rm -f "$PKG/.env"
fi

#
# 6. 安全检查：包内不得残留环境文件 / 密钥 / 安装锁 / 生成清单
#
echo "==> 安全检查"
LEAK=$(find "$PKG" \( -name '.env' -o -name 'oauth-*.key' -o -name 'install.lock' \) -print -quit)
if [ -n "$LEAK" ]; then
    echo "[错误] 包内含敏感文件：$LEAK" >&2
    exit 1
fi
if [ -n "$(find "$PKG/bootstrap/cache" -type f ! -name '.gitignore' -print -quit)" ]; then
    echo "[错误] bootstrap/cache 内仍有生成文件" >&2
    exit 1
fi
echo "    未发现 .env / Passport 密钥 / install.lock / bootstrap 生成缓存"

#
# 7. 打包
#
echo "==> 生成 zip"
/bin/rm -f "$DIST/$NAME.zip"
( cd "$STAGE" && zip -q -9 -r "$DIST/$NAME.zip" "$NAME" )

# 以 root 打包时把产物属主交还 www，避免面板无法读写
if [ "$(id -u)" = "0" ] && id www >/dev/null 2>&1; then
    chown www:www "$DIST/$NAME.zip" || true
fi

echo
echo "==> 完成：$DIST/$NAME.zip"
echo "    文件数：$(find "$PKG" -type f | wc -l)"
echo "    体积：$(du -h "$DIST/$NAME.zip" | cut -f1)"
echo "    顶层内容：$(ls -A "$PKG" | tr '\n' ' ')"
echo "    storage 骨架：$(cd "$PKG/storage" && find . -type d | sed 's|^\./||' | grep -v '^\.$' | tr '\n' ' ')"
