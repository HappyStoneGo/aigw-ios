# AIGW iOS 客户端

对接 [aigw-backend](https://github.com/ikooc/aigw-backend) 的原生 iOS 客户端（SwiftUI）。
后端是 PHP 8.2 + MySQL 的 AI 聚合网关，对外提供 OpenAI 兼容接口 `/v1/*` 与用户端接口 `/api/user/*`。
本工程把这些能力搬到手机上：流式对话 + 完整用户控制台。

> 后端仓库不包含任何 iOS 客户端，本工程是独立编写的客户端实现。

## 能力对照

| 模块 | 覆盖的接口 |
| --- | --- |
| 对话 | `POST /v1/chat/completions`（SSE 流式）、`POST /v1/responses`、`GET /v1/models`、`GET /v1/health` |
| 账号 | `register-config`、`email-code`、`register`、`login`、`logout`、`me`、`password`、`api-key/regenerate` |
| 概览 | `dashboard`、`account-pool/overview`、`logs/stats`、`accounts/credits/monitor` |
| 账号池 | `accounts`、`refresh-all`、`checkin-all`、`tasks-all`、`travel-all`、`activity-all`、各类日志 |
| 供应商 | `providers`（查看 / 测试） |
| 模型 | `models`、`models/sync`、`models/toggle-provider`、`model-profiles` |
| 思维注入 | `personas`、`personas/selfcheck`、`prompt-templates`、`settings`、`chat-settings` |
| 会话资产 | `worldbook`、`character-cards`、`memory`、`memory/recall`、`memory/clear` |
| 扩展 | `mcp`、`mcp/tools`、`plugins`、`subagent/runs`、`workflows`、`tools`、`research`、`speech/*`、`env/*` |
| 套餐 | `plan`、`plan/generate` |
| 日志审计 | `logs`、`logs/stats`、`audit`、`audit/timeline` |

## 目录结构

```
AIGW/
  App/AIGWApp.swift            入口 + 引导页
  Net/ApiClient.swift          HTTP / Cookie 会话 / SSE 流式
  Net/API.swift                108 个用户端接口常量
  Net/CaptchaImage.swift       图形验证码（PNG + 会话 Cookie）
  Store/AppState.swift         全局状态、会话持久化
  Views/Chat/                  对话列表、流式对话、Markdown 渲染
  Views/Panels/                控制台各模块
  Views/Auth/LoginView.swift   登录 / 注册（验证码、邮箱验证）
  Views/SettingsView.swift     服务器地址、API Key、账号
AIGW.xcodeproj                 工程文件（含共享 Scheme）
.github/workflows/build-ipa.yml  云编译出未签名 ipa
tools/genproj.py              pbxproj 生成脚本（新增源文件后可重跑）
```

## 本地编译（macOS + Xcode 15+）

```bash
open AIGW.xcodeproj
# 真机运行需在 Signing & Capabilities 里选择自己的 Team
xcodebuild -project AIGW.xcodeproj -scheme AIGW \
  -configuration Release -sdk iphoneos \
  -archivePath build/AIGW.xcarchive archive
```

## 生成未签名 ipa（GitHub Actions）

1. 新建仓库，把本目录内容推到 `main` 分支。
2. Actions 会自动执行 `Build unsigned IPA`；也可在 Actions 页面手动 `Run workflow`，
   可填写 Bundle ID / 显示名 / 默认服务器地址。
3. 产出 artifact `AIGW-unsigned-ipa`，内含 `AIGW-unsigned.ipa` 与 sha256。

本地复刻打包步骤：

```bash
mkdir -p build/Payload
cp -R build/AIGW.xcarchive/Products/Applications/AIGW.app build/Payload/
cd build && zip -qry AIGW-unsigned.ipa Payload
```

## 安装（未签名包的三种路径）

| 方式 | 前提 | 说明 |
| --- | --- | --- |
| TrollStore | iOS 14.0–17.0（视机型） | 直接打开 ipa 安装，永久签 |
| AltStore / SideStore | 任意 iOS，需 Apple ID | 自签，7 天续签 |
| 轻松签 / Esign | 任意 iOS | 用个人证书或企业证书重签后安装 |

未签名 ipa 直接点开安装会失败（`ApplicationVerificationFailed`），必须先重签。

## 服务器地址

默认 `http://127.0.0.1`，可在首次引导页或「设置 → 服务器」修改。
若网关跑在同一台设备上（例如本机 PHP 服务），`127.0.0.1` 可用；
否则填局域网 IP（如 `http://192.168.1.10:8080`）或域名。

`Info.plist` 已开启 `NSAllowsArbitraryLoads` 与 `NSAllowsLocalNetworking`，
允许 HTTP 明文与局域网访问（自签场景必需）。

## 鉴权说明

- 控制台接口用 Cookie 会话（`aigw_session`），本工程自己管理 Cookie 并持久化。
- 对话接口用 Bearer（`sk-aigw-*` 或 `sk-user-*`），在「设置 → 对话」或登录后自动带入。

## 已知限制

- 供应商新增、OAuth 登录、插件 / 工作流编辑器目前提供查看与调用，创建请走网页控制台。
- `UIFileSharingEnabled` 已开启，`Documents/conversations.json` 可导出对话。
