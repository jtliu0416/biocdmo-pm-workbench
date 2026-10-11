# BioCDMO PM Project File References

该 bundle 为已经以 DSH Workspace 打开的 BioCDMO 项目目录提供轻量的 **文件引用** 机制，不再在普通对话中显示项目选择条、项目目录入口或自定义文件树。

## 文件引用：快速指定一份文件

在项目 Workspace 的右侧原生 `工作区文件` 中，**文件行与文件夹行右侧各有 `引用` 按钮**。点击对应行的按钮会直接把精确路径插入当前输入框，不需要先打开预览或点击灰色的顶部按钮。Composer 上方会显示确认引用的轻量 Chip：

```text
▣ IP266-Meeting Minutes-0621.xlsx  文件 · 已加入输入框  ×
```

引用文件夹只指定该目录路径和范围，**不递归读取、展开或上传整个文件夹**。点击 `引用` 后，输入框插入一行**原生 `@` 引用语法**（与手动输入 `@文件` 完全一致，可被 Composer 原生识别和补全），文件另附只读查询到的版本：

```text
@//C-FILESERVER/06-项目管理部/01-Project-Ongoing/IP266/03-项目启动/
@//C-FILESERVER/.../项目会进展汇报 PPT-IP266.pptx（版本 …）
```

路径含空格时按原生语法加引号（`@"路径"`）；若路径含编辑器无法安全表示的字符，则回退为 `【项目文件引用】路径` 纯文本标记。针对引用路径的安全规则（仅限该路径、文件夹先确认再批量、写操作先说明再执行）统一放在 PM 系统提示 `preset/system-prompt.md` 的“文件引用约定”。引用文件时通过只读 `workspaceFiles.stat` 附带版本；插入成功才显示 Chip，Chip 的 `×` 只关闭提示、不删除已插入文字。

文档预览工具栏中的 `引用到对话` 仍然保留，作为在预览文件时的备用入口。

这样你可以直接写：

```text
提取这份文件的核心意思。
检查这份文件是否有遗漏或风险。
给这份文件加密。
```

无需手动复制完整 UNC 路径，也不会用“右边那个文件”这种模糊指代。

## 允许的项目根

| 项目 | 文件服务器根目录 |
|---|---|
| IP266 | `\\intbio.com\group\06-项目管理部-宋莉\01-Project-Ongoing\IP266` |
| IP322 | `\\intbio.com\group\06-项目管理部-宋莉\01-Project-Ongoing\IP322` |
| IP160 | `\\intbio.com\group\06-项目管理部-宋莉\01-Project-Ongoing\IP160` |

**这张表只描述当前部署**：运行时的唯一来源是 `projects.json`（见上「可移植性」）。其他 PM 用自己的映射替换后，文件引用按钮与归档目标都会自动跟随，无需改代码。

也支持截图中实际 Workspace 使用的 `\\C-FILESERVER\06-项目管理部\01-Project-Ongoing\IP266`（以及同一父目录的 IP322、IP160）；同一份后端目录可能存在多种 UNC 拼写（`intbio.com` 与 `C-FILESERVER`），配置时填**该 PM 实际打开的工作区路径**即可。

文件引用按钮不会出现在这些根目录以外的文件预览中。项目映射不授予任何额外文件权限；Agent 文件操作继续遵守 Session 权限、Sandbox 和 Windows ACL。

> 📘 开发教训与架构约定（**改动本功能前必读**）：[docs/pm-workbench-dev-lessons.md](<../docs/pm-workbench-dev-lessons.md>)
> 📦 分发与配置（装到别的机器 / 别的 PM）：[docs/pm-workbench-deployment.md](<../docs/pm-workbench-deployment.md>)

## 会议纪要面板（右侧栏「📅 会议纪要」标签）

面板由 [client.js](<pm-workbench/client.js>)（全部 UI 与取数）+ [archive-minutes.ps1](<pm-workbench/archive-minutes.ps1>)（归档脚本）+ 项目内缓存目录 `.pm-cache` 组成。数据来自本机已登录的钉钉 `dws` CLI。

> **架构决定（勿回退）**：面板**不注册任何宿主路由**。历史上一度用 `ctx.webServer.register('/pm-minutes/*')` 让面板直连宿主取数，结果反复踩坑：宿主插件 apply 调用时机不可控（导出 name/inject 后 cordis 直接不再 apply）、热加载注销路由却不重新 apply、每次改宿主代码都要重启 DSH。现在面板**只读缓存文件**，经 better-sidebar 已有的 `/sidebar/file` 接口，改客户端刷新页面即生效。见 [index.js](<pm-workbench/index.js>) 顶部的同一条教训说明与 verify.ps1 的守卫。

**数据通道**

```text
<项目根>\.pm-cache\minutes-list.json            听记列表（由 dws minutes +list-all 生成）
<项目根>\.pm-cache\minutes-detail\<uuid>.json   每条听记详情（摘要/行动项/关键词/逐字稿）
<项目根>\.pm-cache\archive-index.json           归档索引（uuid + 项目 → 归档目录）
```

缓存在**用户目录**（面板用 `~/.pm-workbench/cache/...` 读取，better-sidebar 宿主把 `~` 展开为 `%USERPROFILE%`）：**跟人走、与项目解耦、多 PM 零冲突、切项目无需重新同步**。面板代码里只有 `~` 形式，无任何绝对路径。

**交互**

| 操作 | 行为 | 需要 AI？ |
|---|---|---|
| 点条目标题 | 内置浏览器标签打开钉钉听记原页 | 否 |
| 点 `▸` | 展开面板内摘要（读 `.pm-cache\minutes-detail\<uuid>.json`） | 否 |
| `⟳` | 重新读取列表与归档状态（纯本地文件读取） | 否 |
| `📥 归档`（在日期行最右侧） | 把归档指令发给 Agent，由它运行 `archive-minutes.ps1`（确定性脚本） | 是（脚本必须由进程执行） |
| `📂 打开`（已归档时出现，在日期行最右侧） | 打开原生「文件」标签 + `session.openWorkspacePath({action:'reveal'})` 定位归档目录 | 否 |

**刷新语义**：`⟳` 只重读本地缓存，不会去钉钉拉新；要让面板出现**新开会**的听记，需运行 `dws` 重新生成 `.pm-cache`（由 Agent 在对话里执行，或归档流程顺带刷新）。

**归档包结构**（脚本一次产出，目录 `<项目根>\06-项目会会议纪要\<项目ID>-<yyyy.MM.dd>-<标题>\`）

```text
01-会议纪要-<标题>.docx    正式纪要（标题/基本信息/AI摘要/行动项/关键词/转写全文）
01-会议纪要-<标题>.md      同内容 Markdown（侧栏可直接阅读；Word 在本环境不能内联预览）
02-录音-<标题>.mp3         原始录音（钉钉 OSS 限时地址，脚本立即下载；过期则记 warning 不判失败）
03-AI摘要-<标题>.md        钉钉原始 Markdown 摘要
04-行动项-<标题>.csv       序号/行动项/负责人/截止时间/来源（可导入表格）
05-逐字稿-<标题>.md        发言人 + 原文
06-关键词-<标题>.md
```

**归档状态规则（按“当前项目”判定）**

- 索引键 = `uuid + 项目`：同一听记**允许归档到多个项目**（跨项目会议是真实场景）；
- 当前工作区项目已归档 → 🟢`✅ 已归档`，按钮变 `📂 已归档`；
- 仅其他项目已归档 → 🟡`📦 已归档于 IP266`，按钮仍是 `📥 归档`（＝归档到当前项目）；
- 从未归档 → 无徽标，按钮 `📥 归档`；
- 同项目重复归档由脚本按 `uuid + 项目` 拦截，返回 `alreadyArchived`（覆盖须显式 `-Force`）；
- **项目归属永远取自会话工作区路径**（工作区路径中的 `IP\d{3}`），从不询问 PM 在多个项目间选择。

## 当前限制

- File Chip 是当前 Session 中最近一次成功插入引用的确认提示；`×` 只关闭提示，不移除 Composer 的文本。如需撤销引用，请删除输入框内的引用文字。本阶段尚未将路径/版本作为持久的结构化会话事件保存。
- 单击引用不会读取文件正文，也不会自动把正文发送给模型；Agent 在收到明确任务后，仍须依据路径和现有工具权限读取文件。
- 当前 Chip 一次只显示最近一条 PM 路径引用；输入框中此前插入的引用文字并不会自动清除。行级按钮以 DSH 当前原生文件树 DOM 为锚点，未来若 DSH 更改该结构，需要更新插件。

## 技能快捷：文件加密

引用一份文件后，Composer 上方会出现技能快捷条（当前一个技能）：

```text
🔒 加密此文件
```

点击即自动填写并发送加密请求，由 Agent 运行 [encrypt-office.ps1](<pm-workbench/encrypt-office.ps1>)：

- Office 原生打开密码（Excel/Word/PowerPoint COM 自动化）；
- 默认另存 `原名-加密.ext` 副本，原文件保留；
- 密码按项目固定，存放于**项目根目录的隐藏文件 `.pm-password`**（`\\C-FILESERVER\06-项目管理部\01-Project-Ongoing\<项目ID>\.pm-password`）：多 PM 共享同一项目目录即可共用密码，换电脑、换账户均可用；
- 密码读取顺序：① 本机 DPAPI（`%APPDATA%\pm-workbench\passwords.json`，兼容旧设置）；② 项目目录 `.pm-password`。任一存在即自动加密，无需交互；
- **首次加密某项目**（尚无密码）时，Agent 会在对话中提醒 PM 输入一次密码，写入 `.pm-password` 后即完成加密，此后全自动；
- 每个项目密码独立互不串用；密码不显示在脚本输出，也不在后续回复中重复；
- 加密脚本本身绝不弹窗（Agent 后台会话弹窗会卡死），也不会用无密码尝试打开加密文件；
- 支持 .xlsx/.xlsm/.xls/.docx/.docm/.doc/.pptx/.pptm/.ppt。

## 技能快捷条：PPT 合并

PM 在对话中说"合并近N天的PPT"（N 缺省 3），由 Agent 运行 [merge-ppt.ps1](<pm-workbench/merge-ppt.ps1>) 两步完成：

- **Scan**：扫描 `05-项目进展汇报\01-*~12-*` 各部门文件夹（排除 00-SUM 输出目录），每部门只取最近修改的一份 `.pptx`，输出候选清单（含被舍弃的旧版本）；Agent 以表格请 PM 确认/剔除；
- **Merge**：按部门编号顺序合并确认后的文件。封面/尾页取模板第 4/23 页（封面自动写入项目号与汇报日期）；模板查找顺序：① 项目根目录 `PPT模板.pptx`（项目自有模板优先）② preset 目录 `PPT模板-默认.pptx`（公司统一模板，项目未放模板时兜底）；每份源 PPT **保留首页作部门分隔页**、只去末页，保留各部门源格式；
- 输出到 `00-SUM\<项目ID>-项目进展汇报-合并-<yyyy.M.d>.pptx`，已存在须 PM 确认后覆盖；
- 文件被占用或页数<3 会自动跳过并在结果中说明；合并后 PM 人工检查再自行发邮件（不含邮件环节）。
- 支持 .pptx（暂不支持老 .ppt 格式）。

## Skills 化（系统提示词瘦身）

加密与 PPT 合并的详细操作手册已迁出系统提示词，改为按需加载的 DSH Skills：

- Skill 源文件（随 preset 移植）：`<preset根目录>\skills\file-encryption\SKILL.md`、`<preset根目录>\skills\ppt-merge\SKILL.md`
- 系统提示词（system-prompt.md）只保留触发规则（"加密→file-encryption"、"合并PPT→ppt-merge"）和安全红线（密码不回显、严禁临时命令检查 PPT、覆盖需确认）
- **部署/移植时**：把 preset 里的 `skills\` 下两个文件夹复制到本机 `%USERPROFILE%\.agents\skills\`（DSH 从该目录加载 skill），脚本本体仍在 preset 中由 SKILL.md 指引调用
- verify.ps1 会校验 preset 中 skill 源文件存在且包含强制约束内容

## 验证

运行 `verify.ps1` 会验证项目 allowlist、UNC 根、索引文件边界和引用入口；运行 `node verify-client.cjs` 会模拟原生文件树 DOM，验证行级按钮、文件夹与文件引用内容、版本和跨项目路径拒绝。测试不读取文件正文。最后还需在实际 IP266 会话中点击并观察 Composer 以完成 UI 端到端验收。
