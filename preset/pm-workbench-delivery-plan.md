# PM Workbench 实施计划、验收标准与风险控制

## 推荐开发顺序

### Milestone 0：产品验证（无需连接企业系统）

交付：线框图、项目映射 fixture、脱敏文件夹、现有 PM preset/工作流。

验收：PM 能通过本地项目样例完成会议纪要、行动项、风险和周报，并能够在文件树中定位证据。

### Milestone 1：Project Shell

交付：

- 一个 Host + Client 双端 DSH bundle。
- `PM Workbench` 侧边栏入口（使用 `sidebar.panellist`）。
- `main` keyed Project Workspace 页面。
- 本地 Project Navigator 与 Dashboard，按当前 PM 的项目分配进行筛选。
- Context Bar 和 PM 快捷动作。
- PMS MCP 未就绪时，使用带审计的 PM → project_id → UNC file root 管理映射。

验收：

- 可以在 5 个以上 fixture 项目间切换。
- 每个项目显示 RAG、下个里程碑、行动项、客户依赖和最后更新时间。
- 当前项目上下文在 Chat 内可见并可切换。
- 不覆盖 DSH 原有 sidebar、conversation 或 workspace UI。

### Milestone 2：File Server Read-only

交付：

- 显式项目根目录映射配置。
- 文件树、元数据、只读预览和目录变化通知。
- Document Index 与来源链接。
- PDF/Word/Excel 内容提取的受控队列。

验收：

- 访问无权限、空目录、网络错误和文件锁定能清晰区分并告知用户。
- 文件树不越过配置的项目 root。
- 文件索引可追溯至源路径、版本/修改时间。
- 没有删除、移动、重命名、覆盖或上传操作。

### Milestone 3：Project Intelligence

交付：

- Document → Fact / Action / Risk 提取。
- 去重、来源证据、PM Review 队列。
- Meeting Minutes、Weekly Review、Client Follow-up 快捷工作流。
- 现有 `timeline_check`、`action_query`、`project_search` 迁入 Host service。

验收：

- 同一行动项在多份会议资料中可关联而非盲目重复。
- 未知负责人/日期为 `TBD`，不猜测。
- 高风险客户草稿出现 `PM Review Required`。
- 每个项目结论能跳转到文件、会议或 Timeline 证据。

### Milestone 4：Timeline MCP + 企业沟通

交付：

- 自研项目系统 MCP 的 Timeline Adapter。
- 阿里企业邮箱和钉钉只读 Adapter。
- Timeline、邮件、钉钉线索冲突检查。
- 客户和内部沟通草稿队列。

验收：

- Timeline 的 approved baseline、版本和更新时间可见。
- 客户邮件日期冲突不会静默覆盖 Timeline。
- 钉钉内部讨论不会自动展示到客户版输出。
- 默认不发信、不发钉钉、不写回业务系统。

### Milestone 5：Controlled Write（独立立项）

仅在安全、权限、审计和业务验收完成后考虑。

交付：变更预览、PM 确认、幂等写入、版本检查、审计日志、回滚策略。

## 关键技术决策

| 决策 | 建议 |
|---|---|
| UI 入口 | 添加 `sidebar.panellist`，不替换现有 sidebar |
| 主内容页 | `main` keyed slot，key 为 `pm-workbench` |
| 文件预览 | 使用既有右侧 Document/Office Slots，必要时添加 PM metadata tab |
| 项目状态 | Host 内缓存 + 明确 source/version；不能依赖 LLM 记忆 |
| 文件权限 | OS/文件服务器 ACL 是最终授权；插件仅收窄到项目 root |
| 项目主数据 | 自研项目系统 approved Timeline；未接 MCP 前为导入/fixture |
| 写操作 | MVP 禁止；以后显式确认 + 审计 |

## 风险控制

### 数据隔离

- 每次查询都绑定 `project_id` 和已验证 `file_root`。
- 不允许项目 A 的附件、邮件、钉钉摘要进入项目 B 的上下文。
- 组合项目报告需显式选择项目集合。

### 客户与质量风险

- 延期、质量事件、偏差/OOS/CAPA、合同、价格、批次放行、法规结论始终有 `PM Review Required`。
- 不将内部钉钉讨论自动复制到客户输出。
- 客户邮件和合同原文需要按公司敏感级别进行访问控制。

### 可用性与同步

- 明显展示 `last sync`、`source version`、`stale`。
- 无法读取时显示错误，不能显示过期数据而不标明。
- 文件服务器离线不影响已保存的草稿，但不得伪造实时状态。

## 试点建议

选择 3 个项目：

1. Green：流程正常，用于验证快速周报。
2. Amber：有客户依赖，用于验证风险和催办。
3. Red：已有明确升级，用于验证证据、内部升级和客户边界。

试点周期 2–4 周，记录：

- PM 每周节省时间。
- Action 提取准确度和重复率。
- 周报/纪要人工修订比例。
- Timeline 日期冲突发现数量。
- 文件定位时间。
