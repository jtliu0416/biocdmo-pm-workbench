# 项目文件服务器适配方案（已验证 Windows 共享根目录）

## 已验证环境

PM Workbench 可以读取以下 Windows UNC 根目录：

```text
\\intbio.com\group\06-项目管理部-宋莉\01-Project-Ongoing
```

该目录的直接子目录以项目编号为主，例如 `IP1001`、`IP149`、`IP330（原PP253）`，也包含历史/状态目录，例如 `IP272-已终止`、`IP338-项目暂停`，以及项目模板目录 `IPXXX-文件夹模板`。

## 真实项目模板分类

已从 `IPXXX-文件夹模板` 读取到如下标准一级目录：

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

其中已确认：

```text
04-项目计划
├─ 01-项目工作计划
└─ 02-文件交付计划

06-项目会会议纪要
└─ IPXXX 项目会议纪要.xlsx
```

> Workbench 必须使用以上真实目录分类，而不是此前的通用 CDMO 文件夹假设。

## 项目发现规则

### 候选项目目录

默认扫描根目录的直接子目录，但不直接把所有目录展示给 PM。

候选规则：

```text
- 文件夹名以 IP 或 PP 项目编号模式开始
- 不等于 IPXXX-文件夹模板
- 读取项目状态前不假设“当前目录 = 进行中项目”
- 名称带 已终止 / 项目暂停 / 终止协议签订中 时，标为非默认展示
```

### 目录状态分类

| 目录名称线索 | Workbench 默认状态 | 是否展示在“我的项目” |
|---|---|---|
| 无结束/暂停标记 | Candidate Ongoing | 仅 PMS 分配后展示 |
| `已终止` | Terminated | 默认隐藏，保留过滤器 |
| `项目暂停` | Paused | 默认隐藏或单独分组 |
| `终止协议签订中` | Closing | 默认隐藏或单独分组 |
| `文件夹模板` | Template | 永不作为项目展示 |

目录名只是文件服务器线索，**正式项目状态仍以 PMS 为准**。

## 按项目经理筛选：PMS 为主

你确认项目归属应按项目经理，而 PMS 已有项目组组织架构。因此文件服务器不承担“谁负责哪个项目”的判断。

```text
PMS organization / project assignment
       ↓
PM Workbench: 当前登录用户的 PM identity
       ↓
查询该 PM 负责的 active project_id 列表
       ↓
将 project_id 映射至文件服务器目录
       ↓
只显示这些项目的文件与工作台
```

### PMS 最小字段需求

```json
{
  "project_id": "IP330",
  "project_name": "optional",
  "status": "active | paused | closing | terminated",
  "project_manager_user_id": "pms-user-id",
  "project_team": [{"user_id":"...","role":"PM | Tech Transfer | QA"}],
  "timeline_baseline_version": "optional",
  "updated_at": "timestamp"
}
```

### 映射表（PMS MCP 完成前）

在 MCP 未接入时，使用管理员维护的最小映射：

```json
{
  "project_id": "IP330",
  "pms_project_id": "pms-uuid",
  "file_root": "\\\\intbio.com\\group\\06-项目管理部-宋莉\\01-Project-Ongoing\\IP330（原PP253）",
  "folder_name": "IP330（原PP253）",
  "status_hint": "ongoing",
  "access_mode": "read-only"
}
```

映射不应由 LLM 根据相似项目编号自动推断。诸如 `IP149`、`ID149系列(原PP171系列)`、`IP192（原IP174项目）` 都需由 PMS ID 或管理员映射明确关联。

## MVP 文件导航

### 左侧项目列表

```text
我的项目（从 PMS 分配）
├─ IP330 · 项目名称 · Amber
├─ IP350 · 项目名称 · Green
└─ IP338 · 项目暂停（可选显示）
```

### 右侧文件树

当前项目绑定其明确 `file_root` 后，优先展示：

```text
04-项目计划
05-项目进展汇报
06-项目会会议纪要
07-项目管理记录文件
09-项目复盘
```

`01-协议`、`02-项目工时预算`、`08-申报资料支持性文件` 仍可浏览，但默认标注相应敏感级别；是否允许被 AI 提取或进入上下文需要企业权限规则。

### PM 快捷入口

| 快捷入口 | 默认文件范围 | 输出 |
|---|---|---|
| 整理会议纪要 | `06-项目会会议纪要` + 用户选中文件 | 内外部纪要、行动项、风险、草稿 |
| 生成周报 | `04-项目计划`、`05-项目进展汇报`、已确认 Timeline | 内部周报、客户周报草稿 |
| 项目复盘 | `09-项目复盘` + PM 手选材料 | 复盘草稿、经验项 |
| 查看项目管理记录 | `07-项目管理记录文件` | 决策、行动项、风险证据 |

## 安全边界

- UNC 文件服务器的 ACL 是最终访问控制；Workbench 不应绕过 Windows 权限。
- Host 插件只能列出被映射并且当前 PM 有权限的项目 root。
- 不得以“根目录扫描”展示未分配项目给当前 PM。
- 第一期只读：列表、预览、摘要、索引、提取、打开源文件链接。
- 未接入 PMS 前，项目分配和文件夹映射由 PM Admin 维护并保留审计记录。
