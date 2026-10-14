# PM Workbench 开发教训与架构约定

> **读者**：以后维护/扩展这个 preset 的 Agent 或开发者（尤其是未来的我）。
> **目的**：把「会议纪要面板」这一功能反复踩过的坑固化下来，防止再犯。
> **一句话结论**：**面板只读用户目录的中央缓存（`~/.pm-workbench/cache/`，经 better-sidebar 文件接口读取）；禁止再引入任何宿主路由或宿主 HTTP 服务；不要把缓存放回共享的项目文件夹（多 PM 会冲突）。**

---

## 1. 最终架构（当前生效版本）

```text
┌─────────────────────────────┐        只读文件        ┌──────────────────────────────────┐
│ 右侧栏「📅 会议纪要」面板        │ ───────────────────▶ │ <项目根>\.pm-cache\               │
│ client.js（DSH Web 客户端半边）│  /sidebar/file?       │   minutes-list.json              │
│  · 列表 / 分组 / 搜索           │  sessionId&path=      │   minutes-detail\<uuid>.json     │
│  · ▸ 展开详情                   │                       │   archive-index.json             │
│  · ⟳ 本机重读（零 AI）          │                       └──────────────────────────────────┘
│  · 📥 归档 → 发指令给 Agent      │                                     ▲
│  · 📂 已归档 → 原生文件树 + 资源管理器 │                                     │ 生成/更新
└─────────────────────────────┘                                     │
                                                                   │
   Agent（有进程权限）───────────────────────────────────────────────┘
     · dws minutes +list-all / +detail → 写 minutes-list / minutes-detail
     · pwsh archive-minutes.ps1 → 写归档包 + 同步 archive-index
```

| 组件 | 职责 | 是否需要 AI |
|---|---|---|
| `client.js` | 全部 UI 与取数（只读 `.pm-cache`） | 否 |
| `.pm-cache\*.json` | 数据载体（列表 / 详情 / 归档索引） | 否（由脚本或 Agent 生成） |
| `archive-minutes.ps1` | 确定性归档（01~06 编号包 + 索引同步） | 脚本本身不需要 AI，但**必须有进程执行**（由 Agent 触发） |
| `index.js` | **仅 12 行存根**，有意为空 | — |

**责任边界**：
- **只读展示**（列表、详情、刷新、打开归档位置）→ 纯客户端，改代码刷新页面即生效；
- **需要跑进程**（拉取钉钉新听记、归档落盘）→ 只能由 Agent 执行。面板按钮的作用是"发一条明确指令"，不是"自己执行"。

---

## 2. 我们犯过的错（逐条：现象 → 根因 → 教训 → 现有守卫）

### 2.1 宿主路由方案的反复 404（最惨的一次，占了整晚）

- **现象**：面板持续显示"纪要服务不可达 / HTTP 404"，无论重启多少次 DSH 都是 404。
- **根因（两个叠加）**：
  1. 为了让插件"对齐 qa 范式"，给宿主入口加了 `export const name = 'pm-workbench'` 与 `export const inject = []`。**cordis 加载器从此不再调用我们的 `apply()`**，路由永远不会注册。日志特征是：只有 `host module loaded`，**没有** `apply called`。
  2. 宿主代码**没有热加载**：改了 `index.js` 之后，热加载会**注销已注册的路由**、却**不会重新执行 apply**（实测：改完文件后日志零新增，`/pm-minutes/ping` 依旧 404）。
- **教训**：
  - 宿主插件**只导出 `apply`**，不要导出 `name` / `inject`；
  - 宿主代码的任何改动都**必须重启 DSH** 才生效 → 这条本身就说明"宿主路由"不适合作为日常功能的地基；
  - 不要把"重启"当万能钥匙，反复重启解决不了加载器契约问题。
- **现有守卫**：`verify.ps1` 出现 `export const (name|inject)` 直接报错；`index.js` 只保留 `export function apply()`。

### 2.2 注册即注销 / 模块级副作用

- **现象**：某次重启后路由短暂可用，随后消失。
- **根因**：`webServer.register(...)` 之后误留一行 `for (const d of disposers) d();`——注册完立刻把 4 条路由全部注销；此外模块级还放了 `setInterval`、`globalThis` 写入、`fs.readFileSync` 等项目，求值阶段一出错就会让 apply 不被调用。
- **教训**：模块级**只放零风险声明**（imports、常量、函数、导出）；有副作用的事全部放进 `apply()`；注册与注销要成对且只在生命周期回调里发生。
- **现有守卫**：`index.js` 已是空存根；`verify.ps1` 禁止 `webServer.register` / `ROUTE_BASE` 复活。

### 2.3 用自己的测试日志污染真实诊断日志（导致误判）

- **现象**：我一度以为"DSh 启动时 apply 被调用过"，并据此给出错误结论。
- **根因**：冒烟测试脚本与真实宿主写**同一个** `%TEMP%\pm-workbench-host.log`，测试里的假 ctx 恰好也打印 `apply called`；那几条"成功记录"其实是测试进程写的。
- **教训**：排障日志必须**单一来源**；测试必须写到独立目录（现在测试固定把 `process.env.TEMP` 指到 `pm-smoke`）。
- **现有做法**：`index.js` 已无日志代码；测试独立日志目录。

### 2.4 把 `.docx` 当作可在侧栏预览的文件

- **现象**：点"打开会议纪要"→ "此文件类型不支持预览"，只有一个"下载查看"。
- **根因**：本环境侧栏编辑器不支持 Word 内联预览。
- **教训**：归档包**同时产出 Markdown 版**（`01-会议纪要-<标题>.md`）供侧栏阅读；Word 只作正式交付件。

### 2.5 试图让原生文件树"定位到某个目录"

- **现象**：传目录给文件树后出现红字 `"…" is a directory`。
- **根因（读 DSH 源码确认）**：
  - 工作区资源**只有** `dsh-resource://file`，目录会被拒（`file/not-directory`）；
  - 原生文件树的状态初始化是 `start(tab.id, cwd, signal)`——**根永远等于会话 cwd，不接受任何路径参数**，因此"定位到任意目录"在当前 DSH 版本做不到。
- **现有做法**：`📂 已归档` 同时做两件原生的事——(1) `openTabIn(sid, 'files')` 打开原生文件树；(2) `session.openWorkspacePath({ path, action: 'reveal' })` 在资源管理器定位（与预览器"打开"按钮同一原生通道）。

### 2.6 React hooks 顺序 / 面板空白

- **现象**：面板打开全白。
- **根因**：把 `if (renderErr) return …` 放在了 `useState` 之间 → 首次状态更新时 hooks 数量不一致 → React 卸载整棵子树。
- **教训**：**永远不要在 hooks 之间写条件 return**；错误用内联横幅渲染。

### 2.7 项目归属：不该问 PM 在多个项目间选择

- **教训**：项目号**取自当前会话工作区路径**（`IP\d{3}`）；工作区识别不到时才提示切工作区，**绝不列出 IP266/IP322/IP160 让 PM 挑**。
- **归档索引键 = `uuid + 项目`**：同一听记允许归档到多个项目（跨项目会议真实存在）；"已归档"按**当前项目**判定（本项目已归档 🟢`✅`，仅他项目归档 🟡`📦 已归档于 IPxxx`）。

### 2.9 往 DSH profile 写 JSON 带 BOM → 整个宿主启动崩溃（最严重的一次）

- **现象**：DSH 重启后完全不可用，崩溃日志 `DesktopHostFatalError: Unexpected token '\ufeff' … is not valid JSON`，所有插件（包括我们和其他第三方）都没被加载。
- **根因**：profile 的 `package.json` 被写入时带了 **UTF-8 BOM**（`EF BB BF`）。DSH 的 `readProfileManifest` 用 `JSON.parse` 严格解析，BOM 直接崩溃。写入来源：PowerShell 5.1 的 `Set-Content -Encoding UTF8`（必写 BOM）与 dsh-email 插件的安装脚本（同样的 bug，已在其 GitHub 反馈）。
- **教训**：
  1. 凡是写 **JSON**（尤其 profile 的 package.json / cordis.yml），必须**无 BOM UTF-8**：用 `fs.writeFileSync(p, t, 'utf8')`（Node）或 `[IO.File]::WriteAllText(p, t, UTF8Encoding($false))`（PS），**绝不用 PS5.1 的 `Set-Content -Encoding UTF8`**；
  2. 相反，**.ps1 脚本必须带 BOM**（否则 PS5.1 把 UTF-8 中文解析成乱码）——两类文件规则相反，极易搞混；
  3. 修这种崩溃：先查崩溃日志（logs\crash-*-host.log），备份坏文件后**无 BOM 重写**，再 `pnpm install` 清理依赖与 lockfile。
- **现有守卫**：新增 profile 健康检查（无 BOM + JSON 可解析 + 我们的包在册 + 已废弃插件无残留）。

### 2.8 硬编码个人/服务器路径（可移植性）

- **教训**：不得出现 `C:\Users\<某人>\…`、个人缓存目录等；缓存放**项目内的 `.pm-cache`（相对路径）**；归档脚本解析顺序 `-ProjectRoot` → 环境变量 `PM_PROJECT_ROOT` → `projects.json`。
- **现有守卫**：`verify.ps1` 对 `client.js` / `index.js` / `archive-minutes.ps1` 三份文件做硬编码扫描，出现个人路径即报错。

---

## 3. 禁止事项（If you are tempted, read section 2 again）

1. ❌ 在 `index.js` 里注册任何宿主路由（`webServer.register`）、起 HTTP 服务、或让面板 fetch 自建接口。
2. ❌ 给宿主入口导出 `name` / `inject`。
3. ❌ 在模块级放副作用（定时器、全局写、文件 I/O）。
4. ❌ 依赖"改宿主代码 + 重启"来迭代日常功能；客户端能力优先（热加载、刷新即生效）。
5. ❌ 把 Word/Excel 当作可内联预览的文件。
6. ❌ 用目录路径去调用文件资源接口（`openResource` / 树参数）。
7. ❌ 让 PM 在多个项目之间手工选择归属。
8. ❌ 为了让测试通过而在生产日志里写测试信息。
9. ❌ 用 PowerShell 5.1 `Set-Content -Encoding UTF8` 写任何 JSON 文件（必带 BOM，DSH 启动直接崩溃）。
10. ❌ 安装未经 BOM 审查的第三方插件安装器（dsh-email 的安装脚本就有此 bug，已在麒麟座/上游反馈前保持卸载）。

---

## 4. DSH 插件开发要点（实测结论，省得再摸）

| 主题 | 结论 |
|---|---|
| 客户端半边 | **热加载**：改 `client.js` 刷新页面即生效（无需重启） |
| 宿主半边 | **不热加载**：改 `index.js` 必须重启 DSH；且热加载会注销旧路由而不重新 apply |
| 宿主入口契约 | 只要 `export function apply(ctx)`；**不要** `name` / `inject` |
| `webServer` 访问 | 宿主上下文中它是直接属性 `ctx.webServer`（`ctx.keys=[webServer,effect]`），不是 `ctx.get('webServer')`（虽然历史上曾两说并存，当前实测以直接属性为准） |
| 可选服务探测 | 客户端**不要** `inject` 可选服务（会 park fiber → 白屏）；用 `ctx.get(...)` 探测 + `ctx.on('internal/service')` 补注册 |
| 面板注册 | `ctx.get('betterSidebar').registerTab({ id, title, component, order, single })`；`TabComponentProps` 含 `ctx` / `scope`（`sessionId`、`cwd`）/ `tab` / `visible` |
| 打开发送 | 面板内的 DOM 事件里没有原生 `window.open` 权限保障，统一走服务：浏览器标签 `sidebarRight.openTabIn(sid,'browser',{params:{url}})`；文件 `openResource('dsh-resource://file/session/<sid>/<相对或绝对路径>')` 或 `betterSidebar.openFile(scope, path)` |
| 读文件 | better-sidebar 路由：`/sidebar/file?sessionId=<sid>&path=<相对 cwd 或绝对路径>`（面板只读缓存就靠它） |
| 列目录 | better-sidebar 路由：`POST /sidebar/api/fs.tree` body `{ sessionId, cwd, path }` → `{ path, entries:[{name,path,isDir,…}], truncated }` |
| 枚举标签类型 | `betterSidebar` 服务无 list 接口；用 `ctx.get('sidebarRightTabs')`（宿主注册表有 `get`/`entries`） |
| 检查路由是否在线 | `better-sidebar` 的 `/sidebar/api/*` 返回非 404 即在线（例如 `POST /sidebar/api/fs.tree` → 500 `session not found` 也算在线） |

---

## 5. 排障手册（现象 → 先查什么）

| 现象 | 先查 | 结论方向 |
|---|---|---|
| 面板空白 | 浏览器控制台 hooks 报错 / `MinutesBoundary` 横幅 | hooks 顺序或渲染异常 |
| "纪要服务不可达 / HTTP 404" | 是否又引入了宿主路由 | **本手册第 3 节第 1 条**：改回 `.pm-cache` |
| 列表空 / "读取不到" | `<项目根>\.pm-cache\minutes-list.json` 是否存在、`sessionId` 是否为空 | 缓存未生成 → 让 Agent 跑一次 dws 同步 |
| 详情展不开 | `.pm-cache\minutes-detail\<uuid>.json` 是否存在 | 缓存详情缺失 → 重新同步 |
| 打开目录报 `is a directory` | 是否把目录丢给了资源/编辑器 | 用 `📂 已归档` 的原生双通道 |
| Word 打不开/不能预览 | 是否点了 `.docx` 当预览 | 改点 `01-会议纪要-*.md` |
| 改了宿主代码没效果 | 日志有没有新的 `apply` 记录 | 宿主不热加载 → 需重启；但优先考虑"这功能该不该放宿主" |

---

## 6. 验收与守卫（每次改动后必须全绿）

```powershell
# 1) 资源与架构校验（含可移植性 + 禁止宿主路由 + 禁止 name/inject 导出）
pwsh -File pm-workbench\verify.ps1

# 2) 客户端行为测试（模拟原生文件树 DOM，验证引用按钮与版本号）
node pm-workbench\verify-client.cjs
```

守卫覆盖：项目 allowlist、UNC 根与索引边界、文件引用行为、**架构守卫（禁止宿主路由复活）**、**可移植性守卫（禁止个人路径）**、本文档存在性。

---

## 8. 分发与配置

装到另一台机器 / 另一位 PM 的依赖链、安装顺序与验收清单见 [pm-workbench-deployment.md](<pm-workbench-deployment.md>)。

## 7. 变更记录

| 日期 | 变更 |
|---|---|
| 2026-10-11 | 删除全部宿主路由（`index.js` 356 → 12 行存根）；面板改为只读项目 `.pm-cache`；移除 `name`/`inject` 导出；`⟳` 改为纯本地重读（删除经 AI 的刷新按钮）；归档改由 Agent 运行脚本并同步索引；加入架构与可移植性守卫；本文档建立 |
| 2026-10-10 | 面板 MVP：钉钉听记列表 / 详情 / 归档（01~06 编号包）、归档状态徽标、原生文件树与资源管理器定位 |
