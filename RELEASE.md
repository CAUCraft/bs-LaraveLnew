# 发版指南（Release）

本仓库是 [Blessing Skin Server](https://github.com/bs-community/blessing-skin-server) `6.0.2` 的定制发行版，

本文档说明如何发布一个正式版本（含 GitHub Actions 自动发版、本地打包、产物校验与回滚）。

---

## 1. 版本号规范

采用 `上游版本-R<修订号>`：

| 示例 | 含义 |
| --- | --- |
| `6.0.2-R1` | 基于上游 6.0.2 的第 1 次本地修订（当前版本） |
| `6.0.2-R2` | 同一上游版本的第二次修订（修 bug，不升上游版本号） |
| `6.0.3` | 跟上游 6.0.3 同步（不带 `-R` 后缀） |

对应规则：

- 源码版本号：`config/app.php` 的 `'version'`、`package.json` 的 `"version"`，两处必须一致；
- Git tag：`v` + 版本号，例如 `v6.0.2-R1`；
- 安装包名：`blessing-skin-server-<版本号>.zip`，例如 `blessing-skin-server-6.0.2-R1.zip`。

> ⚠️ tag 与 `config/app.php` 里的版本号不一致时，Actions 会**直接失败**并提示，这是有意设计，避免发出错版本号。

---

## 2. 发版产物说明

`tools/release.sh` 采用**白名单打包**，产物与上一版官方正式包（`6.0.2`）保持同一套"干净骨架"口径：

```text
blessing-skin-server-6.0.2-R1/
├── app/  bootstrap/  config/  database/  routes/  resources/  public/  vendor/
├── artisan  index.html  composer.json          # composer.json 供 Laravel 读取命名空间
├── .env.example                                # 保留：chkenv.php 据此自动生成 .env
├── LICENSE  README.md  README-zh.md  QUICKSTART.md
├── plugins/                                    # 空（用户自行安装插件）
├── bootstrap/cache/                            # 仅 .gitignore，不带 packages.php/services.php
└── storage/                                    # 仅空目录骨架，每个目录只有 .gitignore
    ├── app/public/  logs/
    ├── framework/{cache/data,sessions,views}/
    └── packages/  debugbar/  textures/
```

**绝不会进包**：`.env`（含数据库密码 / APP_KEY）、`storage/oauth-*.key`、`storage/install.lock`、
编译视图、日志、session、缓存、`resources/assets` 前端源码、`*.map`、`plugins` 实装内容、
`public/lang/*.js`（运行时自动生成）、`node_modules`、`dist`。

`release.sh` 打包结束前会做**安全检查**：发现 `.env` / `oauth-*.key` / `install.lock` /
`bootstrap/cache` 生成物会直接失败退出。

---

## 3. 发版前检查清单

- [ ] 功能改动已提交，工作区干净（`git status` 无未提交内容）
- [ ] 安装器补丁仍在 `app/Http/Controllers/SetupController.php`（`generatePassportKeys` 方法）
      —— 重新覆盖上游源码后必须确认这处修复没被冲掉
- [ ] `config/app.php` 与 `package.json` 版本号已同时更新且一致
- [ ] 前端能正常构建（本地：`yarn install && bash tools/build-assets.sh`）
- [ ] `bash tools/release.sh` 本地试跑通过（或依赖 Actions 构建）
- [ ] 若本次涉及数据库变更：确认迁移脚本已随代码提交
- [ ] 无需提交敏感文件：`.env`、`storage/oauth-*.key`、`storage/install.lock`（已在 `.gitignore` 中）

---

## 4. 方式 A：GitHub Actions 自动发版（推荐）

工作流文件：`.github/workflows/release.yml`

**触发条件**

| 事件 | 行为 |
| --- | --- |
| 推送 `v*` tag | 构建安装包 → 创建 GitHub Release（附 zip + SHA256SUMS.txt） |
| 手动 Run workflow | 仅构建安装包 → 上传为 workflow artifact（不创建 Release，用于预演/自测） |

**执行步骤**

1. 更新版本号（二选一）

   ```bash
   # 推荐：脚本自动同步两处版本号
   bash tools/bump-version.sh 6.0.2-R1 --commit

   # 或手工改 config/app.php 的 'version' 与 package.json 的 "version"
   ```

2. 提交并打 tag（`--tag` 会一并提交）

   ```bash
   git tag -a v6.0.2-R1 -m "Blessing Skin Server 6.0.2-R1"
   ```

3. 推送代码与 tag

   ```bash
   git push origin HEAD --follow-tags
   ```

4. 打开 GitHub 仓库 → **Actions → Release**，确认构建通过

5. 打开 **Releases**，编辑自动生成的 Release（建议按第 6 节模板补发版说明）

**工作流内部流程**

```text
checkout → 读版本号并校验 tag
        → setup PHP 8.4（mbstring/gd/zip/imagick/bcmath/intl/...）
        → composer install --no-dev（写入 vendor/）
        → setup Node 20 + yarn install --frozen-lockfile
        → bash tools/build-assets.sh（webpack 构建 public/app，补拷 favicon.ico / bg.webp）
        → bash tools/release.sh --no-composer（白名单打包 + 安全检查）
        → sha256sum 生成校验和
        → upload-artifact（始终）
        → softprops/action-gh-release（仅 tag 触发）
```

> 首次使用前请在 GitHub 仓库 **Settings → Actions → General** 确认
> Workflow permissions 为 **Read and write permissions**（工作流已声明 `contents: write`，
> 若组织策略更严格，可能需要额外放行）。

---

## 5. 方式 B：服务器本地打包（宝塔 / 不走 CI）

```bash
# 1. 前端资源（首次或前端代码变更后必须执行）
yarn install
bash tools/build-assets.sh

# 2. 打包（宝塔环境需 root：php 在 /www/server/php/84/bin/php，不在 PATH）
sudo bash tools/release.sh

# 只看流程不跑 composer（vendor 已是 --no-dev 时）
sudo bash tools/release.sh --no-composer

# 3. 产物
ls -lh dist/blessing-skin-server-6.0.2-R1.zip
sha256sum dist/*.zip
```

打包脚本会用 `php artisan --version` 做**启动冒烟测试**，通过后清理临时缓存再压包；
产物属主会自动交还 `www:www`，宝塔面板可直接下载。

---

## 6. Release Notes 模板

发版时直接复制下面模板到 GitHub Release 描述里：

```markdown
## Blessing Skin Server 6.0.2-R1

基于上游 6.0.2 的第 1 次本地修订，目标环境：宝塔面板 + Nginx + PHP 8.4 + MySQL 8。

### 安装包

- `blessing-skin-server-6.0.2-R1.zip`（已剔除 `.env`、运行时缓存、密钥与前端源码）
- `SHA256SUMS.txt`（校验：`sha256sum -c SHA256SUMS.txt`）

### 变更

- 修复 Web 安装向导 500：`The command "passport:keys" does not exist.`
  - 原因：Laravel Passport 仅在 console 环境注册 `passport:*` 命令，安装向导在 HTTP 请求中调用 Artisan
  - 方案：`SetupController` 内直接生成 4096 位 RSA 密钥（等价官方 `passport:keys`）
- 新增 Linux 打包脚本 `tools/release.sh`、前端构建脚本 `tools/build-assets.sh`、版本号脚本 `tools/bump-version.sh`
- 新增 GitHub Actions 自动发版流程（tag `v*` 触发）
- 仓库与安装包统一"干净骨架"口径（无 `.env` / 无运行时缓存 / 无插件实装内容）

### 升级方式

1. 备份 `.env`、`storage/`、`plugins/`、数据库
2. 解压新包覆盖程序目录（**不要**覆盖 `.env`、`storage/`、`plugins/`）
3. 执行 `php artisan migrate --force`
4. 清理缓存：`php artisan view:clear && php artisan config:clear`
5. 访问站点确认版本号与皮肤功能正常

### 环境要求

PHP 8.4（`pdo_mysql` `mbstring` `bcmath` `gd` `imagick` `zip` `fileinfo` `curl` `openssl` `intl`）、
MySQL 8、Nginx（站点根目录指向 `public` + Laravel 伪静态）。
```

---

## 7. 升级已有站点（覆盖安装注意）

安装包**不含** `.env`、`storage/` 运行时数据、`plugins/` 实装插件，覆盖升级时请务必保留：

```bash
# 备份
cp .env /tmp/bs-env.bak
tar czf /tmp/bs-storage.tgz storage
tar czf /tmp/bs-plugins.tgz plugins

# 解压新包到临时目录后，只覆盖程序文件（app config database routes resources public vendor artisan ...）
# 不要执行 cp -r 整包覆盖，避免把 storage/ 骨架盖掉正式数据
```

随后执行迁移与缓存清理：

```bash
sudo /www/server/php/84/bin/php artisan migrate --force
sudo /www/server/php/84/bin/php artisan view:clear
sudo /www/server/php/84/bin/php artisan config:clear
```

> 升级后 `.env` 中的 `APP_KEY` 必须保持不变，否则已登录用户与加密数据会失效。

---

## 8. 回滚

```bash
# 代码回滚
git checkout <上一个 tag>   # 或重新部署上一版 zip

# 数据库回滚（仅当本次含迁移）
sudo /www/server/php/84/bin/php artisan migrate:rollback --step=1

# 清理缓存
sudo /www/server/php/84/bin/php artisan view:clear
sudo /www/server/php/84/bin/php artisan config:clear
```

---

## 9. 常见问题

| 现象 | 原因 / 处理 |
| --- | --- |
| Actions 报 "tag 与版本号不一致" | 先 `bash tools/bump-version.sh <tag去掉v>` 提交后再打 tag |
| Actions 报 `public/app 为空` | 构建前端失败，检查 `yarn install` 步骤日志 |
| Actions 报缺 `ext-imagick` | `setup-php` 的 `extensions` 列表被改动，恢复 `imagick` |
| 本地打包提示找不到 php | 宝塔下 php 不在 PATH，用 `sudo bash tools/release.sh`，脚本会自动用 `/www/server/php/84/bin/php` |
| composer 报 lock 文件版本过旧 | 使用项目内 `tools/composer.phar`（2.8.x），系统自带 2.0 读不了 lock |
| 安装向导仍 500 `passport:keys` | 说明 `SetupController` 的补丁被上游源码覆盖，重新应用 `generatePassportKeys()` |
| 升级后版本号没变 | `config/app.php` 未更新，或 `bootstrap/cache/config.php` 旧缓存未清 |

---

## 10. 相关文件

| 路径 | 作用 |
| --- | --- |
| `.github/workflows/release.yml` | GitHub Actions 发版流程 |
| `tools/release.sh` | 安装包打包（白名单 + 安全检查 + 冒烟测试） |
| `tools/build-assets.sh` | 前端资源构建（webpack + 静态文件拷贝） |
| `tools/bump-version.sh` | 版本号同步（`config/app.php` + `package.json`，可提交/打 tag） |
| `tools/composer.phar` | Composer 2.8.x（本地打包用，不入仓库） |
| `.gitignore` | 与安装包同一套"干净骨架"口径 |
