# PM Workbench：对话内项目文件浏览重构

## 决策

文件操作不应以独立 `PM Workbench` 主页面为主要入口。PM 的日常工作应该保持在现有 DSH 对话中：一边和 PM Harness 对话，一边浏览当前项目文件、预览单一文件，并把**用户明确选中的文件**带入后续请求。

`PM Workbench` 主页面保留为可选的“项目组合 / PM Desk”入口；文件使用体验迁移到 Conversation。

## 目标体验

```text
┌──────────────────────┬──────────────────────────────────────┬─────────────────────────┐
│ 左侧：当前项目文件树  │ 中间：现有 DSH 对话                   │ 右侧：文件预览 / AI 面板 │
│                      │                                      │                         │
│ 项目：IP160 ▼         │ PM Harness 对话                       │ IP160会议纪要-2026...   │
│                      │                                      │                         │
│ ▾ 05-项目进展汇报     │ 用户：请根据所选会议纪要整理行动项。   │ [预览] [元数据] [摘要]   │
│   ▸ 00-SUM            │                                      │                         │
│   ▸ 03-CCPD           │ 助手：已使用“IP160会议纪要...”作为    │ 文件路径、时间、大小      │
│   • IP160-项目...pptx │ 唯一文件上下文，输出行动项草稿。       │ Office / PDF 预览         │
│                      │                                      │                         │
│ ▾ 06-项目会会议纪要   │ [项目上下文：IP160]                   │ [加入对话上下文]          │
│   • IP160会议纪要...   │ [已选文件：1]                          │ [生成摘要（草稿）]        │
└──────────────────────┴──────────────────────────────────────┴─────────────────────────┘
```

## 布局映射到当前 DSH

### 1. 左侧：不替换 DSH 整体 Sidebar

DSH 的根 `sidebar` 是单一、已占用的 Shell 区域，替换会破坏会话列表。因此不替换它。

推荐方式：

- 在 `conversation.session.header.actions` 添加 **项目文件** 按钮；
- 点击后打开一个会话范围的 Project File Drawer；
- Drawer 呈现为对话左侧的第二列 / 可折叠面板，保留最左侧原始 DSH 会话导航。

这符合“现有对话左侧插入目录结构”的体验，同时不覆盖 Harness 的会话导航。

### 2. 中间：保留现有 Conversation

- 不替换 `main.conversation`、聊天记录或 Composer。
- 用 `conversation.input.dock` 显示当前项目和已选文件：

```text
项目：IP160  ·  Read-only  ·  已选文件：IP160会议纪要-2026.9.17.xlsx [清除]
```

- 文件只有在 PM 点击 **加入对话上下文** 后，才作为明确上下文进入下一次请求。

### 3. 右侧：复用现有右栏 / 文档预览能力

现有 DSH 已含：

```text
ui-sidebar-right
ui-sidebar-documentpreview
ui-sidebar-files
office-to-pdf
```

文件选择后：

1. 右栏打开文件预览；
2. 优先使用 DSH Office/PDF 预览能力；
3. 右栏增加 PM Metadata / PM Summary Tab；
4. 未经 PM 操作，不将文件正文自动放进对话或模型上下文。

## 交互流程

### A. 浏览与预览（不调用模型）

```text
选择项目 IP160
  → 展开 06-项目会会议纪要
  → 点击 IP160会议纪要-2026.9.17.xlsx
  → 右栏预览 + 显示元数据
```

仅此操作不读取或分析其他文件，也不创建对话附件。

### B. 明确使用文件生成草稿

```text
右栏点击“加入对话上下文”
  → 对话底部显示已选文件标识
  → PM 输入任务，例如“整理行动项、风险和客户待确认事项”
  → Host 对该一份 allowlisted 文件执行受控只读正文提取
  → PM Harness 输出 Facts / Actions / Risks / Questions 草稿
```

### C. 多文件场景

- 默认最多 3 个明确选择的文件；
- 每个文件在 Context Bar 中可见、可移除；
- 跨项目选择被拒绝；
- “选择整个文件夹”不等于“上传整个文件夹”；必须逐一选择文件或使用受控批量工作流。

## 项目上下文规则

### 当前项目来源

MVP：用户从工作台项目清单中选择 `IP266`、`IP322` 或 `IP160`。

将来：由 PMS MCP 返回“当前登录 PM 负责的 active project”列表。

### 会话绑定

```text
Session PM Context
├─ project_id: IP160
├─ file_root: explicit UNC root
├─ selected_files: [{relative_path, version/mtime, source_ref}]
└─ mode: read-only / draft-only
```

- 当前项目在会话中明确可见；
- 新会话默认无项目，PM 必须选择项目；
- 同一会话切换项目时，要求 PM 确认是否清除已选文件；
- 不能将 IP160 文件静默带入 IP266 对话。

## 文件目录范围

第一阶段显示：

```text
04-项目计划
05-项目进展汇报
06-项目会会议纪要
07-项目管理记录文件
09-项目复盘（或 IP266 的 08-项目复盘）
```

默认不向模型开放、但可按企业授权单独浏览的敏感目录：

```text
01-协议
02-项目工时预算
08-申报资料支持性文件
```

## 安全设计

- 目录树只能由明确项目 allowlist 和对应 `file_root` 生成。
- Host 需验证 `project_id → file_root → relative_path`，拒绝绝对路径或 `..` 越界。
- 文件选择不等于授权模型访问其他同目录文件。
- 预览、正文读取、摘要生成均只读。
- 文件摘要必须有 `source_ref`、文件修改时间和提取时间。
- 行动项、风险、客户待确认事项永远先以 `Proposed` 草稿显示。
- “发送”“写回”“替换文件”不出现在该文件浏览器中。

## 分阶段实现

### Phase A：Conversation File Browser Shell

- 会话 Header 加 `项目文件` 按钮。
- Drawer 文件树使用现有 allowlist + 目录元数据。
- 文件点击打开现有 DSH 右栏预览。
- `conversation.input.dock` 显示 Project Context Bar。

### Phase B：受控单文件正文读取

- 支持 Excel / Word / PDF / PowerPoint 单文件文本提取。
- PM 明确点击“加入对话上下文”。
- 文件内容作为带来源的会话上下文进入 PM Harness。
- 支持摘要、事实、行动项、风险草稿。

### Phase C：项目文件智能

- 文件版本比较。
- 会议纪要与已有行动项去重。
- 文件事实对照 Timeline MCP。
- 文件改动通知与待审阅队列。
