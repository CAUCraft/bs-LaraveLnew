#!/usr/bin/env bash
#
# 构建前端静态资源（webpack），等价于上游的 tools/build.ps1
#
# 产物：public/app/  （js / css / ttf / woff2 / wasm / *.twig 模板 + 静态图片）
#
# 说明：
#   - public/app 已在 .gitignore 中，不入仓库；release 包与 Docker/CI 构建时
#     都必须先跑本脚本，否则安装包会缺少前端资源（页面白屏）。
#   - webpack 只负责打包，favicon.ico 与 bg.webp 属于静态文件，需要手动拷贝，
#     这是上游 build.ps1 里被容易忽略的一步。
#
# 用法：
#   bash tools/build-assets.sh            # 清理后重新构建
#   bash tools/build-assets.sh --no-clean # 不清理 public/app，直接增量构建
#
set -euo pipefail

ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
cd "$ROOT"

CLEAN=1
for arg in "$@"; do
    case "$arg" in
        --no-clean) CLEAN=0 ;;
        -h|--help) sed -n '2,18p' "${BASH_SOURCE[0]}" | sed 's/^# \{0,1\}//'; exit 0 ;;
        *) echo "未知参数：$arg" >&2; exit 1 ;;
    esac
done

#
# 1. 选择包管理器（优先 yarn，其次 npm）
#
if command -v yarn >/dev/null 2>&1; then
    RUN="yarn build"
elif command -v npm >/dev/null 2>&1; then
    RUN="npm run build"
else
    echo "[错误] 未找到 yarn 或 npm，请先安装 Node.js 依赖" >&2
    exit 1
fi

#
# 2. 清理旧产物
#
if [ "$CLEAN" = 1 ] && [ -d public/app ]; then
    echo "==> 清理 public/app"
    /bin/rm -rf public/app
fi
mkdir -p public/app

#
# 3. webpack 生产构建
#
echo "==> 构建前端资源：$RUN"
$RUN

#
# 4. 拷贝静态文件（webpack 不处理这两个）
#
echo "==> 拷贝静态文件"
for f in bg.webp favicon.ico; do
    src="resources/assets/src/images/$f"
    if [ -f "$src" ]; then
        cp "$src" public/app/
        echo "    public/app/$f"
    else
        echo "    [警告] 缺少静态文件：$src"
    fi
done

#
# 5. 校验产物
#
if [ ! -f public/app/favicon.ico ]; then
    echo "[错误] public/app/favicon.ico 缺失（站点默认 favicon_url=app/favicon.ico）" >&2
    exit 1
fi
if [ -z "$(find public/app -maxdepth 1 -name '*.js' -print -quit)" ]; then
    echo "[错误] public/app 下没有生成任何 js，前端构建失败" >&2
    exit 1
fi

echo
echo "==> 完成：public/app 共 $(find public/app -type f | wc -l) 个文件，$(du -sh public/app | cut -f1)"
