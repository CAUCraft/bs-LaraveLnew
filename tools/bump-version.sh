#!/usr/bin/env bash
#
# 版本号bump：同步修改 config/app.php 与 package.json，可选自动 commit + tag
#
# 用法：
#   bash tools/bump-version.sh 6.0.2-R2              # 只改文件
#   bash tools/bump-version.sh 6.0.2-R2 --commit     # 改文件并提交
#   bash tools/bump-version.sh 6.0.2-R2 --tag        # 改文件、提交并打 tag（隐含 --commit）
#
# 版本号规则（推荐）：<上游版本>-R<n>
#   例：6.0.2-R1 = 基于上游 6.0.2 的第 1 次本地修订
#
# tag 命名：v<版本号>，例如 v6.0.2-R1
#   推送 tag 后 GitHub Actions（.github/workflows/release.yml）会自动构建并发版。
#
set -euo pipefail

ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
cd "$ROOT"

NEW_VERSION="${1:-}"
if [ -z "$NEW_VERSION" ]; then
    echo "用法：bash tools/bump-version.sh <新版本号> [--commit|--tag]" >&2
    echo "当前版本：$(sed -nE "s/.*'version'[[:space:]]*=>[[:space:]]*'([^']+)'.*/\1/p" config/app.php | head -1)" >&2
    exit 1
fi

if ! printf '%s' "$NEW_VERSION" | grep -Eq '^[0-9]+\.[0-9]+\.[0-9]+(-[0-9A-Za-z.]+)?$'; then
    echo "[错误] 版本号格式不合法：$NEW_VERSION（示例：6.0.2-R1 / 6.0.3 / 6.1.0-beta.1）" >&2
    exit 1
fi

DO_COMMIT=0
DO_TAG=0
for arg in "${@:2}"; do
    case "$arg" in
        --commit) DO_COMMIT=1 ;;
        --tag) DO_COMMIT=1; DO_TAG=1 ;;
        *) echo "未知参数：$arg" >&2; exit 1 ;;
    esac
done

OLD_VERSION=$(sed -nE "s/.*'version'[[:space:]]*=>[[:space:]]*'([^']+)'.*/\1/p" config/app.php | head -1)

echo "==> 版本号：$OLD_VERSION → $NEW_VERSION"

sed -i -E "s/'version'[[:space:]]*=>[[:space:]]*'[^']*'/'version' => '$NEW_VERSION'/" config/app.php
sed -i -E "0,/\"version\":[[:space:]]*\"[^\"]*\"/s//\"version\": \"$NEW_VERSION\"/" package.json

# 交叉校验，避免 sed 静默失败
PHP_VER=$(sed -nE "s/.*'version'[[:space:]]*=>[[:space:]]*'([^']+)'.*/\1/p" config/app.php | head -1)
JSON_VER=$(sed -nE 's/^[[:space:]]*"version":[[:space:]]*"([^"]+)".*/\1/p' package.json | head -1)
if [ "$PHP_VER" != "$NEW_VERSION" ] || [ "$JSON_VER" != "$NEW_VERSION" ]; then
    echo "[错误] 写入后校验失败：config/app.php=$PHP_VER package.json=$JSON_VER" >&2
    exit 1
fi
echo "    config/app.php  -> $PHP_VER"
echo "    package.json    -> $JSON_VER"

if [ "$DO_COMMIT" = 1 ]; then
    git add config/app.php package.json
    git commit -m "chore(release): 版本号 $NEW_VERSION" >/dev/null
    echo "==> 已提交：$(git log --oneline -1)"
fi

if [ "$DO_TAG" = 1 ]; then
    git tag -a "v$NEW_VERSION" -m "Blessing Skin Server $NEW_VERSION"
    echo "==> 已打 tag：v$NEW_VERSION"
    echo "    执行 git push origin HEAD --follow-tags 后，GitHub Actions 会自动构建并发布 Release"
else
    echo
    echo "下一步："
    echo "  1) git add -A && git commit -m \"chore(release): 版本号 $NEW_VERSION\""
    echo "  2) git tag -a v$NEW_VERSION -m \"Blessing Skin Server $NEW_VERSION\""
    echo "  3) git push origin HEAD --follow-tags"
fi
