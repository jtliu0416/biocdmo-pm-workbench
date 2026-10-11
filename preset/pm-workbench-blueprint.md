# BioCDMO PM Workbench 蓝图

## 愿景

把 DeepSeek Harness 从“一个对话界面”扩展为 PM 的项目控制台：项目、文件、Timeline、行动项、会议、客户沟通和风险在同一工作区内可见、可追溯、可由 AI 辅助处理。

## 信息架构

```text
左侧：项目导航                中央：当前项目工作台                   右侧：上下文与文件
├─ 我的项目（RAG）             ├─ 项目总览 Dashboard                 ├─ 项目文件树
├─ 本周关注                    ├─ Timeline / Milestones              ├─ 选中文件预览
├─ 等待客户                    ├─ Actions                             ├─ 文件元数据 / 版本
├─ 有风险项目                  ├─ Risks / Issues / Changes            ├─ AI 提取事实
└─ 项目搜索                    ├─ Meetings                            └─ 相关邮件/钉钉摘要
                                ├─ Client Communications
                                └─ PM Chat
```

## 用户视图

### 1. Project Navigator（左侧）

每个项目一行，显示：

- 项目编号、客户简称、项目名称
- RAG 状态：Green / Amber / Red
- 当前阶段：Tech Transfer / PD / Manufacturing 等
- 本周到期行动项数量
- 等待客户输入数量
- 未读/新增文件提示（未来）

建议分组：`我的项目`、`本周重点`、`等待客户`、`风险项目`、`已归档`。

### 2. Project Dashboard（中心）

顶部固定 Project Header：客户、项目编号、阶段、RAG、PM、最后同步时间、Timeline 版本。

核心卡片：

- **Next 7 Days**：即将到期里程碑和行动项
- **Client Dependencies**：等待客户资料、样品、确认、签字
- **Risks / Issues**：高影响事项和缓解措施
- **Timeline Health**：关键路径、At Risk、延期情景
- **Latest Evidence**：最新客户邮件、钉钉会议、文件版本
- **PM Actions**：一键生成周报、会议纪要、催办邮件草稿、风险评审

### 3. Project Files（右侧或中心 Tab）

文件服务器的项目根目录映射为该项目的文件树。对于当前已验证的项目模板，使用真实一级分类：

```text
01-协议
02-项目工时预算
03-项目启动
04-项目计划
05-项目进展汇报
06-项目会会议纪要
07-项目管理记录文件
08-申报资料支持性文件
09-项目复盘
```

项目必须由 PMS 中“当前登录 PM 负责的 active project”清单筛选后展示；Windows 共享盘只提供文件证据和项目目录映射，不决定项目归属。

每个文件显示：版本、修改时间、来源路径、负责人/上传人（若来源系统提供）、AI 提取的项目标签。

可执行动作：预览、摘要、比较版本、提取行动项、生成会议纪要、归档建议、复制文件链接；删除/移动/覆盖属于 Phase 3 以后受控操作。

## 关键 PM 工作流

### A. 会议后 10 分钟闭环

```text
钉钉会议记录 / 手工笔记 / 文件
  → 提取事实、决议、行动项、风险
  → 与 Timeline 和已有 Action 去重
  → 输出内部纪要 + 客户纪要 + follow-up 邮件草稿
  → PM 审阅
  → 后续受控写回项目系统 / 发信
```

### B. 每周项目控制

```text
Timeline 主数据 + 本周文件 + 邮件 + 钉钉摘要
  → RAG 评估
  → 关键路径与客户依赖
  → 本周完成、下周计划、升级项
  → 内部周报 + 客户周报草稿
```

### C. 文件到项目事实

```text
文件服务器文件
  → 识别项目编号 / 文件类型 / 版本
  → 建立 Project Document Index
  → 提取日期、交付物、责任方、行动项
  → 对照 Timeline / Contract obligation
  → 标记冲突、缺失文件或更新风险
```

## DSH 实现形态

### Client Plugin

- `sidebar.panellist`：新增“PM Workbench”全局面板入口，避免替换 DSH 原始左栏。
- `main` keyed slot：渲染项目工作台主页面。
- `sidebar.right.*` slots：项目文件树、文件预览、AI 摘要、相关资料等 Session 右栏 Tabs。
- `conversation.input.dock`：当前项目上下文条，例如 `PRJ-2025-018 · Amber · Tech Transfer`。
- `conversation.composer.dock`：快捷按钮：会议纪要、周报、催客户、风险评审。

### Host Plugin

- `pmProjectStore`：项目索引、映射、缓存、审计和本地配置。
- `pmFileAdapter`：文件服务器的只读目录列举、文件元数据、文本/Office 提取。
- `pmTimelineAdapter`：未来连接自研系统 MCP；当前读取 fixture/导出。
- `pmMailAdapter`：未来阿里企业邮箱只读检索与草稿出口。
- `pmDingTalkAdapter`：未来钉钉项目群、会议、待办只读查询。
- `pmAnalysis`：统一调用 timeline/action/project-search 和文档抽取能力。

## 文件服务器映射原则

项目根路径不得由模型自由猜测。映射应配置为显式清单：

```json
{
  "project_id": "PRJ-2025-018",
  "display_name": "客户A / mAb-001",
  "file_root": "\\\\fileserver\\CDMO\\PRJ-2025-018",
  "access_mode": "read-only",
  "document_taxonomy": "standard-cdmo-v1"
}
```

第一阶段只允许：列目录、读文件、生成摘要/索引/草稿、打开文件链接。任何重命名、移动、覆盖、删除、上传、归档均必须进入受控写入设计。

## 迭代路线图

### Phase 1 — PM Shell（2–3 周）

- Project Navigator、Dashboard 静态 UI、项目切换。
- 本地 JSON 项目索引和文件夹映射。
- 只读文件列表、文件预览、手工上传。
- 将现有 preset 作为项目内 Chat persona。

### Phase 2 — File Intelligence（2–4 周）

- 文档索引、Word/PDF/Excel 元数据与正文提取。
- 文件版本比较、Action/Risk 提取、会议纪要处理。
- 项目文件与行动项/Timeline 的可追溯链接。

### Phase 3 — Project Control（2–4 周）

- Timeline MCP Adapter（自研系统 MCP 就绪后）。
- RAG、关键路径、延期情景、周报和项目组合视图。
- 内部/客户版输出与 PM 审阅队列。

### Phase 4 — Communication Integration（后续）

- 阿里企业邮箱只读检索、邮件事实对齐、草稿创建。
- 钉钉只读项目群/会议/待办摘要。
- 明确 PM 确认后才能调用发送、发帖、创建待办等副作用。

## 成功标准

- PM 在一个项目页内能在 30 秒内回答：项目状态、下一个里程碑、谁卡住、需要客户做什么。
- 会议结束后 10 分钟内生成可审阅的纪要、行动项和 follow-up 草稿。
- 周报准备从小时级降到 15–30 分钟。
- 每个关键日期和客户承诺能跳回 Timeline、邮件、钉钉或源文件。
- AI 不因摘要而取代已批准 Timeline、合同或质量体系的正式记录。
