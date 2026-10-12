# PM Workbench 分发与配置文档

> **读者**：要把这套 AI PM 工作台装到**另一台机器 / 另一位 PM** 的人。
> **一句话**：这不是"拷一个文件夹"就完事的——它由 **4 个必须组件 + 2 项一次性人工授权** 组成，且有**先后依赖顺序**。本文给出依赖关系、安装顺序、验证方法与常见故障。

---

## 1. 依赖关系图（谁依赖谁）

```text
┌──────────────────────────────────────────────────────────────────────┐
│ ① DSH 桌面版（宿主，必须）                                             │
│    提供：Web GUI(127.0.0.1:19387)、右侧栏、原生「文件」树、内置浏览器、   │
│          cordis 插件系统、会话工作区(UNC 项目目录)、                     │
│          自带运行时 node / pnpm / python                              │
└───────────────┬──────────────────────────────────┬───────────────────┘
                │                                  │
                │ 插件（写进 profile 的 bundles）    │ 运行时
                ▼                                  ▼
┌───────────────────────────────┐   ┌──────────────────────────────────┐
│ ② dsh-better-sidebar 0.25.0   │   │ python  → 生成归档 Word           │
│    （必须，第三方插件）          │   │ node    → 跑 dws / 脚本依赖         │
│    提供：tab 框架 registerTab、  │   │ pnpm    → 安装插件                 │
│          /sidebar/file 文件读取  │   └──────────────────────────────────┘
│          openFile/编辑器        │
└───────────────┬───────────────┘
                │ 我们的面板注册在它的 tab 框架里，数据经它的文件接口读
                ▼
┌──────────────────────────────────────────────────────────────────────┐
│ ③ 我们的 preset 两个包（必须，本仓库目录 link 进 profile）               │
│    @local/dsh-biocdmo-pm-preset     系统提示 / skills / workflows / 模板 │
│    @local/dsh-biocdmo-pm-workbench  「📅 会议纪要」面板 + 文件引用按钮     │
└───────────────┬──────────────────────────────────────────────────────┘
                │ 数据来源
                ▼
┌──────────────────────────────────────────────────────────────────────┐
│ ④ dws（钉钉 Workspace CLI，必须）                                      │
│    唯一数据源：听记列表 / 详情(摘要·行动项·关键词·转写) / 录音             │
│    需要：组织登录（个人扫码一次）                                        │
└───────────────┬──────────────────────────────────────────────────────┘
                │ 由 Agent 运行，落盘成：
                ▼
    <项目根>\.pm-cache\minutes-list.json / minutes-detail\*.json
    <项目根>\06-项目会会议纪要\<项目ID>-<日期>-<标题>\01~06 文件包
                ▲
                │ 面板只读这些文件（经 ② 的 /sidebar/file）
```

**关键结论（容易搞错的地方）**：

| 你以为 | 实际 |
|---|---|
| 装了插件面板就能取数据 | ❌ 还需要 ④ dws 已登录；面板读的是**文件**，文件由 dws 生成 |
| 面板直接调钉钉 CLI | ❌ 面板是网页，不能跑进程；数据由 Agent/脚本跑 dws 落成文件后面板只读（详见 `docs/pm-workbench-dev-lessons.md`） |
| 需要装钉钉桌面客户端 | ❌ 不必须。`dws auth login` 走浏览器扫码；面板"打开原页"用 DSH 内置浏览器登录 `shanji.dingtalk.com`（Cookie 持久化，登录一次长期有效） |
| 需要装 Office/WPS | ❌ 会议纪要不需要（Word 由 python-docx 生成）。仅**文件加密 / PPT 合并**需要本机 Office 或 WPS |

---

## 2. 依赖清单（含验证方法）

| # | 组件 | 是否必须 | 版本基线（已验证） | 安装方式 | 验证命令 / 现象 | 缺失后果 |
|---|---|---|---|---|---|---|
| ① | **DSH 桌面版** | 必须 | `0.2.0-rc.2` | 官方安装包 | 能打开 GUI、能建会话 | 一切无从谈起 |
| ② | **dsh-better-sidebar** | 必须 | `0.25.0`（**锁定此版本**） | 见 §3 步骤 3 | 右侧栏出现"+ 新标签"能力；`POST http://127.0.0.1:19387/sidebar/api/fs.tree` 返回非 404（返回 500 `session not found` 也算在线） | 右侧栏**没有**「📅 会议纪要」标签；面板无数据 |
| ③ | **pm-preset**（本仓库 `dsh-preset\`） | 必须 | `0.1.0` | link 进 profile | 系统提示生效；`skills` 目录可用 | Agent 无 PM 规则与技能 |
| ③ | **pm-workbench**（本仓库 `pm-workbench\`） | 必须 | `0.1.0` | link 进 profile | 右侧栏出现「📅 会议纪要」标签 | 无面板、无文件引用按钮 |
| ④ | **dws（钉钉 CLI）** | 必须 | `v1.0.55`（≥1.0.5x） | `npm i -g dingtalk-workspace-cli` | `dws auth status --format json` → `authenticated: true` | 面板列表永远为空（缓存无法生成） |
| ⑤ | **项目盘读写权限** | 必须 | — | IT/共享盘授权 | 能在 `<项目根>\06-项目会会议纪要\` 新建文件 | 归档失败、缓存写不进去 |
| ⑥ | **skills 复制** | 可选（加密/PPT合并需要） | — | 复制 `preset\skills\*` → `%USERPROFILE%\.agents\skills\` | 目录存在 `file-encryption\SKILL.md` 等 | 加密 / PPT 合并技能不可用（会议纪要不受影响） |
| ⑦ | dshmarket / dsh-mcp-connector | 可选 | `^1.66.14` / `0.2.70` | 市场安装 | — | 只是少了插件市场与 MCP 对接 |
| ⑧ | 钉钉桌面客户端 | 不需要 | — | — | — | — |
| ⑨ | Office / WPS | 仅加密&PPT合并需要 | — | — | — | 会议纪要不受影响 |

---

## 3. 安装顺序（复制即可执行）

> 以下 `%PROFILE%` = `%USERPROFILE%\.dsh\profiles\desktop`（DSH 桌面版的 profile 目录）。
> DSH 自带 node/pnpm 路径示例：`%USERPROFILE%\.dsh\dsh-runtimes\dsh-primary-runtime\dependencies\node\bin\node.exe`

**步骤 1｜装 DSH 桌面版**，打开一次，确认能新建会话并看到右侧栏。

**步骤 2｜装并登录 dws**

```powershell
npm i -g dingtalk-workspace-cli     # 得到 dws 命令
dws auth login                       # 浏览器扫码，一次即可（token ≈3 个月，refresh ≈30 天）
dws auth status --format json        # 期望 authenticated: true 且 corp_name 正确
```

**步骤 3｜装 better-sidebar（第三方插件）**

```powershell
# 在 profile 目录安装（版本锁定，本套功能验证过 0.25.0）
& "$env:USERPROFILE\.dsh\dsh-runtimes\dsh-primary-runtime\dependencies\node\bin\node.exe" `
  "$env:USERPROFILE\.dsh\dsh-runtimes\dsh-primary-runtime\dependencies\pnpm\bin\pnpm.cjs" `
  --dir "$env:USERPROFILE\.dsh\profiles\desktop" add dsh-better-sidebar@0.25.0
```

**步骤 4｜放置 preset 并 link 进 profile**

1. 把本仓库的 `PM\` 目录放到目标机固定位置（例如 `%USERPROFILE%\AI\preset\PM`）；
2. 编辑 `%PROFILE%\package.json`：

```jsonc
{
  "dependencies": {
    "@local/dsh-biocdmo-pm-preset":    "link:C:/Users/<你>/AI/preset/PM/dsh-preset",
    "@local/dsh-biocdmo-pm-workbench": "link:C:/Users/<你>/AI/preset/PM/pm-workbench",
    "dsh-better-sidebar": "0.25.0"
  },
  "dsh": { "profile": { "bundles": [
    "@deepseek-ai/dsh-base",
    "@deepseek-ai/dsh-web-app",
    "@local/dsh-biocdmo-pm-preset",
    "@local/dsh-biocdmo-pm-workbench",
    "dshmarket",
    "dsh-mcp-connector",
    "dsh-better-sidebar"
  ] } }
}
```

3. 在 profile 目录执行一次 `pnpm install`（建立 link）；
4. **重启 DSH 一次**（profile 变更需重启；此后日常使用无需重启）。

**步骤 5｜配置项目映射（唯一配置源）**

编辑 `pm-workbench\projects.json` 的 `projects[].file_root`，填**该 PM 实际打开的工作区路径**（例如 `\\C-FILESERVER\...\IP266` 或 `\\intbio.com\group\...\IP266`）。可选字段：`project_parent`（归档父目录）、`cache_dir`。归档脚本的项目根解析顺序：`-ProjectRoot` → 环境变量 `PM_PROJECT_ROOT` → `projects.json`。

**步骤 6｜部署 skills（可选，加密/PPT 合并需要）**

```powershell
Copy-Item ".\PM\skills\file-encryption" "$env:USERPROFILE\.agents\skills\" -Recurse -Force
Copy-Item ".\PM\skills\ppt-merge"       "$env:USERPROFILE\.agents\skills\" -Recurse -Force
```

**步骤 7｜生成首屏数据（否则面板是空的）**

在 DSH 里把会话工作区切到项目目录（如 `IP266`），让 Agent 执行一次同步（生成 `.pm-cache`）：

```powershell
dws minutes +list-all --format json        # 列表 → .pm-cache\minutes-list.json
dws minutes +detail --id <taskUuid>        # 每条详情 → .pm-cache\minutes-detail\<uuid>.json
```

**步骤 8｜验收清单（逐条打勾）**

```powershell
# a. 面板与 tab
#    右侧栏出现「📅 会议纪要」；点开有列表、能搜索、能分组
# b. 文件读取通道（better-sidebar 在线）
Invoke-WebRequest -Uri 'http://127.0.0.1:19387/sidebar/api/fs.tree' -Method Post `
  -ContentType 'application/json' -Body '{"sessionId":"x"}' -UseBasicParsing   # 期望 500 session not found，不是 404
# c. dws
dws auth status --format json              # authenticated: true
# d. 缓存
Test-Path "\\<项目根>\IP266\.pm-cache\minutes-list.json"
# e. 归档
#    点某条「📥 归档」→ 项目盘 06-项目会会议纪要 下出现 <项目ID>-<日期>-<标题> 文件夹（01~06）
# f. 自检脚本
pwsh -File pm-workbench\verify.ps1
node pm-workbench\verify-client.cjs
```

---

## 3b. 环境切换（测试 ⇄ 生产）

- **唯一开关**：`pm-workbench\projects.json` 的 `projects[].file_root`。改完即生效（归档脚本与校验都从这里解析），无需改代码。
- **本机当前**：测试 = \\C-FILESERVER\… 与 \\intbio.com\group\…（历史产物在测试路径下）；生产 = `G:\06-项目管理部-宋莉\01-Project-Ongoing\<项目ID>`（G: 是 \\intbio.com\group 的映射盘）。
- **映射盘注意**：G: 按用户会话映射。若 DSH 启动后报"路径不存在"，先在资源管理器确认 G: 已连接，或改用 UNC 形式。
- 测试产物清理：删除各测试路径下的 `06-项目会会议纪要\<…>` 文件夹与 `.pm-cache\` 即可（均为派生数据）。

## 4. 每台机器的一次性人工动作

| 动作 | 频率 | 说明 |
|---|---|---|
| DSH 打开一次并重启一次 | 安装时 1 次 | profile 变更需要 |
| `dws auth login` 扫码 | ≈ 每 3 个月 | token 过期时会报 401；重新扫码一次 |
| 在 DSH 内置浏览器登录钉钉 | 1 次（长期） | 仅为"点标题打开钉钉原页"用；Cookie 持久化 |
| 项目盘权限申请 | 1 次 | 需要 `<项目根>` 读写（`.pm-cache` 与归档目录） |

---

## 5. 常见故障对照

| 现象 | 根因 | 处理 |
|---|---|---|
| 右侧栏**没有**「📅 会议纪要」 | better-sidebar 未装 / 版本不符 / bundles 未加 / 未重启 | 按 §3 步骤 3-4 重做并重启一次 |
| 面板有界面但**列表为空** | `.pm-cache` 未生成；或会话工作区不是项目目录 | 切到项目工作区 → 让 Agent 跑一次 dws 同步 |
| 列表点不开详情 | `.pm-cache\minutes-detail\<uuid>.json` 缺失 | 重新同步（包含 `+detail`） |
| 面板报"读取不到" | better-sidebar 的 `/sidebar/file` 不可用（版本变更） | 用 §3 步骤 8b 验证；必要时回退 better-sidebar 到 0.25.0 |
| 归档没反应 | 未在项目工作区 / `archive-minutes.ps1` 找不到 | 切工作区；确认 `pm-workbench\archive-minutes.ps1` 存在 |
| `dws` 报 401 / 权限错误 | 登录过期 / 无该听记读权限 | 重新 `dws auth login`；权限问题见 §7 |
| 详情返回 `RESOURCE_NOT_FOUND` | 企业空间听记未对 API 开放 | 需管理员开通"组织内使用"，见 §7 |
| 点 Word "不支持预览" | 本环境不能内联预览 .docx | 点同目录的 `01-会议纪要-*.md`（侧栏可读） |
| 归档时录音缺失（warning） | 听记已过期 / 无痕模式 | 正常，其余产物照常落盘 |

---

## 6. 升级注意事项（会破坏什么）

| 升级对象 | 风险 | 升级后必须做 |
|---|---|---|
| **dsh-better-sidebar** | tab/文件接口若变更，面板可能消失或读不到缓存（我们用到：`registerTab`、`openFile`、`getTabs`、`/sidebar/file`） | 跑 `verify.ps1` + `verify-client.cjs`，并手动点一遍面板；异常则回退 0.25.0 |
| **DSH 本体** | 宿主 API / 文件树 DOM 可能变化（文件引用按钮锚定原生文件树 DOM） | 同上；并在真实会话里点一次引用按钮 |
| **dws** | 一般向后兼容；新版本会多出官方 `+export-pack`（可替代自研归档脚本） | 无需改动即可继续用；若想切换官方导出，先小样本验证 |
| **本 preset** | — | `verify.ps1` 含架构守卫（禁止宿主路由复活、禁止个人路径、教训文档必须存在） |

---

## 7. 权限与合规前置条件

1. **项目盘**：目标 PM 必须对 `<项目根>` 有读写权限（写入 `.pm-cache` 与 `06-项目会会议纪要`）。
2. **钉钉听记 API 范围**：`dws` 以**个人身份**访问听记。
   - 自己创建 / 共享给自己的听记：可读摘要、行动项、关键词、转写、录音。
   - **企业空间**听记：部分条目的详情/录音会返回 `RESOURCE_NOT_FOUND`，需**管理员为应用开通"组织内使用"**后才可读；面板表现为"详情读取失败"，属于权限而非缺陷。
3. **录音地址为限时 OSS 链接**：归档脚本会在归档时立即下载；过期/无痕听记拿不到地址，只记 warning。
4. **密码文件**：文件加密功能的项目密码存于项目根 `.pm-password`（多 PM 共享同一项目目录即共享密码）；本文档涉及的分发不包含任何密码。
5. **客户版材料**：凡对外内容仍遵守双版本规则与 `PM Review Required` 标注——与本文档的技术分发无关，但别忘。

---

## 8. 相关文档

- 开发教训与架构约定（**改代码前必读**）：[pm-workbench-dev-lessons.md](<pm-workbench-dev-lessons.md>)
- 面板与归档细则：[pm-workbench/README.md](<../pm-workbench/README.md>)
- PM 工作流：[workflows/meeting-minutes.md](<../workflows/meeting-minutes.md>)
