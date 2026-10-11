# 插件与工具架构

## 设计目标

将 PM Harness 分成“项目事实层、业务工具层、呈现层”，先保证可追溯和可替换，再连接企业系统。

```text
Client UI / Preset
       ↓
PM workflows
       ↓
Project Fact Store
       ↓
Adapters: files | email | calendar | spreadsheet | Teams/meeting
```

## 工具边界

### 只读工具（MVP 优先）

- `project_search`：按项目、客户、批次、文件和日期检索事实。
- `document_extract`：读取 Word/PDF/Excel 内容并提取字段、版本和来源。
- `timeline_check`：检查逾期、日期冲突、依赖和关键路径。
- `action_query`：查询逾期、客户待办、本周到期和未分配责任人的行动项。
- `contract_obligation_extract`：从合同/SOW/质量协议提取责任、交付物和日期。

### 生成工具

- `minutes_generate`：生成内部版和客户版会议纪要。
- `weekly_report_generate`：生成内部周报和客户更新稿。
- `email_draft_generate`：基于已确认项目事实生成邮件草稿。
- `risk_review_generate`：生成风险、问题、变更和升级建议。

### 写入工具（MVP 后）

- `project_upsert`
- `action_upsert`
- `milestone_upsert`
- `risk_upsert`
- `document_link`

所有写入工具都应支持幂等 ID、来源字段、变更记录和撤销/修订，而不是静默覆盖。

### 外部副作用工具（最后接入）

- `email_send`
- `calendar_create`
- `file_archive`
- `teams_post`

这些工具应采用“草稿优先、显式目标、发送前摘要、发送后回执”的业务控制，即使运行时 approval policy 为 `never`，也不能将高风险客户沟通默认为自动发送。

## Harness / DSH 对接建议

当前可用的运行时能力包括 Host/Client Service、Event、Config、Tool、Slots、Theme 等 Inspect Provider。开发真正插件前，应通过 Inspect 查询精确 Service、Event、Config、Tool 和 Slot contract，不应把 Inspect method 当成业务 Service 调用。

第一阶段建议只实现 preset 文件和只读分析流程；当真实集成需求确定后，再基于实际 contract 开发插件。

## 权限与数据治理

- 客户/分子/合同数据按项目隔离。
- 文件来源、版本、更新时间必须保留。
- 对外发送前检查收件人、附件、项目编号和敏感信息。
- 日志记录事实变更、生成内容、用户修改和外部发送回执。
- 质量事件和合同信息默认标记为 restricted，按公司权限执行。
