# PM Workbench 数据模型与文件服务器映射

## 设计原则

- 项目系统的 approved Timeline 仍是日期、状态和依赖的主数据。
- PM Workbench 是“索引、关联、分析、草稿和审阅层”，不是 QMS、EDMS、合同系统或正式项目系统的替代品。
- 每条可见事实均尽可能带 `source_ref`、`observed_at`、`source_system`。
- 先保存映射和索引，避免复制完整受限文件；正文和附件仅按权限临时读取或缓存。

## 核心实体

```text
Project
├─ ProjectSourceMapping[]
├─ ProjectFileRoot[]
├─ TimelineSnapshot[]
├─ ActionItem[]
├─ RiskIssueChange[]
├─ MeetingRecord[]
├─ CommunicationRecord[]
├─ DocumentIndexEntry[]
└─ DraftArtifact[]
```

## Project

```json
{
  "project_id": "PRJ-2025-018",
  "display_name": "Client A · mAb-001",
  "client": "Client A",
  "stage": "Tech Transfer",
  "project_manager": "user-id-or-email",
  "rag": "Amber",
  "timeline_source_mode": "fixture | import | mcp",
  "access_mode": "read-only",
  "last_reviewed_at": "2025-04-14T09:42:00+08:00"
}
```

## ProjectFileRoot

```json
{
  "mapping_id": "map-001",
  "project_id": "PRJ-2025-018",
  "root_type": "windows-share | local-sync | sharepoint | upload",
  "root_path": "\\\\fileserver\\CDMO\\PRJ-2025-018",
  "display_path": "CDMO / PRJ-2025-018",
  "access_mode": "read-only",
  "taxonomy": "standard-cdmo-v1",
  "mapping_owner": "PM Admin",
  "validated_at": "2025-04-14T09:42:00+08:00"
}
```

## DocumentIndexEntry

```json
{
  "document_id": "doc-018-gap-v1",
  "project_id": "PRJ-2025-018",
  "relative_path": "03_Tech_Transfer/Gap Analysis v1.0.docx",
  "file_name": "Gap Analysis v1.0.docx",
  "document_type": "gap-analysis",
  "version": "v1.0",
  "modified_at": "2025-04-10T17:30:00+08:00",
  "source_ref": "fileserver://...",
  "content_status": "indexed | extracted | restricted | failed",
  "classification": "internal | client-shareable | restricted",
  "related_entities": ["MS-003", "RISK-001"]
}
```

## Fact and Evidence Model

任何 AI 提取的事实采用：

```json
{
  "fact_id": "fact-001",
  "type": "date | action | risk | decision | commitment",
  "value": "Customer sample arrival planned for 2025-04-18",
  "confidence": "high | medium | low",
  "status": "proposed | confirmed | superseded",
  "source_ref": "document_id or message_id",
  "source_excerpt": "short evidence excerpt",
  "observed_at": "timestamp",
  "reviewed_by": null
}
```

`proposed` 事实不能自动改变 Timeline、Action、Risk 或客户沟通内容。

## 映射配置的管理方式

初版可采用一个由 PM 管理员维护的 JSON/YAML 映射文件；未来由自研系统 MCP 或公司项目主数据服务提供。

```text
project-mappings.json
  → project_id
  → file root
  → folder taxonomy
  → allowed source systems
  → user/team access policy
```

## 文件发现与索引流程

```text
Validate file root access
  → List direct folders/files
  → Identify standard folder category
  → Read metadata
  → Classify file / infer version only from explicit evidence
  → Create index entry
  → Optional content extraction
  → Link proposed facts with source evidence
```

## 写入状态机

```text
read-only
  → draft-only
  → PM-confirmed-write-preview
  → controlled-write
```

第一版固定在 `read-only` 和 `draft-only`。任何进入文件服务器或 Timeline 的写操作都需要单独审批、审计记录和未来接口支持。
