# PM Workbench 页面线框图与关键交互

## 页面一：My PM Desk（默认首页）

```text
┌─────────────────────┬─────────────────────────────────────────────────────┬────────────────────┐
│ BioCDMO PM          │ My PM Desk                                          │ PM Focus           │
│                     │                                                     │                    │
│ [⌂] 项目工作台       │ Good morning, PM                                   │ Today              │
│ [◫] 我的项目          │                                                     │ • 3 client inputs  │
│ [!] 风险与升级        │ Portfolio Health                                   │ • 2 overdue items  │
│ [▣] 文件              │ ┌────────┐ ┌────────┐ ┌────────┐                 │ • 1 review draft   │
│                     │ │ 8 Green│ │2 Amber │ │1 Red   │                 │                    │
│ ─────────────────── │ └────────┘ └────────┘ └────────┘                 │ Needs review       │
│ 我的项目              │                                                     │ • Weekly report    │
│ ● PRJ-018  Amber     │ This Week                                           │ • Client email     │
│ ● PRJ-022  Green     │ ┌─────────────────────────────────────────────────┐│                    │
│ ● PRJ-063  Red       │ │ Project │ Next milestone │ Owner │ Risk        ││                    │
│                     │ └─────────────────────────────────────────────────┘│                    │
│ 等待客户 (3)          │                                                     │                    │
│ 风险项目 (2)          │ [生成周报] [整理会议纪要] [查看本周行动项]         │                    │
└─────────────────────┴─────────────────────────────────────────────────────┴────────────────────┘
```

### 目的

让 PM 在进入一个具体项目之前，先看到项目组合层面今天要推动什么。

### 交互

- 点击项目行进入 Project Workspace。
- 点击 Amber/Red 过滤对应项目。
- `生成周报` 从已选择项目或当前筛选集合创建草稿，不直接发送。
- `Needs review` 显示所有带 `PM Review Required` 的草稿。

## 页面二：Project Workspace

```text
┌─────────────────────┬─────────────────────────────────────────────────────┬────────────────────┐
│ 项目列表              │ PRJ-2025-018 · Client A · mAb-001                  │ Project Evidence   │
│                     │ Tech Transfer  [Amber]  PM: You  Timeline v3.2      │                    │
│ 我的项目              │ Last sync: 09:42                                    │ Files              │
│ ▸ PRJ-018 Amber      ├─────────────────────────────────────────────────────┤ ▾ 02_PM            │
│   PRJ-022 Green      │ [Overview][Timeline][Actions][Risks][Meetings]      │   Timeline v3.2    │
│   PRJ-063 Red        │ [Documents][Communication][PM Chat]                 │   Weekly report    │
│                     ├─────────────────────────────────────────────────────┤ ▸ 03_TechTransfer  │
│                     │ NEXT 7 DAYS       CLIENT DEPENDENCIES                │ ▸ 08_Client Comms  │
│                     │ 4/15 shipping     confirm sample temp/quantity       │                    │
│                     │ 4/17 method list  send complete technical package    │ Selected file      │
│                     │ 4/18 samples      --                                 │ Timeline v3.2.xlsx │
│                     ├─────────────────────────────────────────────────────┤ Version / modified │
│                     │ TIMELINE HEALTH   RISKS / ISSUES                     │ [Preview] [Summary]│
│                     │ Critical path     RISK-001 Medium / High             │ [Compare versions] │
│                     │ Sample → gap      mitigation & owner                 │                    │
│                     ├─────────────────────────────────────────────────────┤ Evidence links     │
│                     │ [会议纪要] [催客户] [项目周报] [风险评审]            │ Timeline / email / │
│                     └─────────────────────────────────────────────────────┘ notes              │
└─────────────────────┴─────────────────────────────────────────────────────┴────────────────────┘
```

### 固定 Project Header

必须持续显示：

- 项目编号、客户、分子/产品、阶段、RAG
- 项目经理
- Timeline baseline / version / last sync
- 当前数据模式：`Read-only`、`Draft-only` 或未来 `Controlled write`

### Tab 设计

| Tab | 用户要回答的问题 | MVP 数据来源 |
|---|---|---|
| Overview | 当前状态、下周重点、客户依赖是什么？ | 项目索引 + Timeline 导出 |
| Timeline | 哪些节点 At Risk、依赖什么、延迟影响什么？ | Timeline Adapter |
| Actions | 谁在什么时候前需要完成什么？ | 项目记录 + 会议提取 |
| Risks | 哪些风险需要缓解、升级或决定？ | Risk Register + 文件证据 |
| Meetings | 最近会议决定了什么？ | 会议记录 / 钉钉导出 |
| Documents | 有哪些文件、版本和缺失？ | 文件服务器映射 |
| Communication | 客户待确认什么、有哪些草稿？ | 邮件导出 / 未来阿里邮箱 |
| PM Chat | 围绕当前项目进行对话 | 选中项目上下文 |

## 页面三：Document Review Drawer

```text
┌──────────────────────────────────────┐
│ Gap Analysis v1.0.docx               │
│ PRJ-2025-018 · 03_Tech Transfer      │
│ Source: \\fileserver\...             │
├──────────────────────────────────────┤
│ [Preview] [AI Summary] [Facts]        │
│ [Actions] [Compare]                  │
├──────────────────────────────────────┤
│ Extracted facts                       │
│ • Target gap assessment: 4/25         │
│ • Depends on samples + package        │
│ • Owner: Tech Transfer                │
│                                      │
│ Proposed actions                      │
│ • Confirm sample shipping parameters  │
│   Owner: Client · Due: 4/15           │
│                                      │
│ [Add to draft action register]        │
│ [Ask PM Chat about this file]         │
└──────────────────────────────────────┘
```

默认只生成“Proposed”信息。写回 Action Register 或项目系统前必须经过 PM 审阅。

## 关键快捷交互

### Context Bar

在聊天输入框上方：

```text
Working in: PRJ-2025-018 · Client A · Amber · Timeline v3.2  [Change project]
```

目的：让 PM 明确当前 AI 使用哪个项目上下文，避免跨项目串数据。

### Composer 快捷按钮

```text
[Meeting Minutes] [Weekly Review] [Client Follow-up] [Risk Review] [Attach Project File]
```

每个按钮先展示将使用的输入资料和输出目标；不隐式选取所有敏感文件。

## 空状态

### 项目尚未映射文件服务器

```text
No file root connected.
[Map project folder] [Use uploaded files only]
```

### Timeline 未接入 MCP

```text
Approved Timeline is not connected.
[Import Excel / CSV] [Use fixture] [Configure MCP later]
```

### 没有权限

```text
You do not have read access to this project folder.
Request access from the project administrator.
```

不能以空结果伪装成“项目没有文件”。
