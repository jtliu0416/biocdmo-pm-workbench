---
name: ppt-merge
description: "Use when the PM asks to merge recent project progress PPTs (合并PPT/合并近N天的PPT) in a BioCDMO project. Runs pm-workbench merge-ppt.ps1 to scan department folders and merge the latest deck per department with a template cover/closing."
---

# 项目进展 PPT 合并

## 用途

把 `05-项目进展汇报` 下各部门（01-RD ~ 12-RA）最近更新的 PPT 汇总成一份完整汇报 PPT（PM 确认后自行发邮件，本功能不含邮件环节）。

## ⚠️ 强制约束

扫描候选、统计页数、合并**全部由 merge-ppt.ps1 完成**。严禁现场编写 python/COM/here-string 临时命令检查或统计 PPT（隐藏 shell 里中文 here-string 必然遇到编码问题；页数统计已内置且经过验证）。Agent 只负责：跑脚本 → 把 JSON 结果转成表格给 PM 确认 → 跑 Merge → 报告。

## 执行步骤

### 第一步：扫描候选

```
pwsh -File "<preset根目录>\pm-workbench\merge-ppt.ps1" -Action Scan -Project <项目ID> -Days <N>
```

- N 以 PM 说的天数为准（"近3天"），未说默认 3。
- 脚本内置规则：排除 00-SUM 输出目录；**每个部门只取修改时间最新的一份**（同部门旧版本为迭代版本，进 `dropped` 列表）；只认 `.pptx`。

### 第二步：PM 确认

把 `candidates` 转成表格呈现（部门 / 文件名 / 修改时间 / 页数），并展示 `dropped` 供核对。PM 可剔除个别部门；汇报日期缺省为今天，PM 可在此环节指定其他日期。

### 第三步：合并

把 PM 确认后的 candidates 存为 JSON 文件（UTF-8），运行：

```
pwsh -File "<preset根目录>\pm-workbench\merge-ppt.ps1" -Action Merge -Project <项目ID> -ListPath <json路径> [-ReportDate yyyy.M.d]
```

- 输出默认 `05-项目进展汇报\00-SUM\<项目ID>-项目进展汇报-合并-<今天yyyy.M.d>.pptx`。
- **输出文件已存在时，必须先向 PM 确认**，确认后加 `-Force` 覆盖。

### 第四步：报告

报告输出路径、合并份数、总页数、跳过清单（`skipped`：被占用或页数<3 的文件）；提醒 PM 人工检查合并结果后再自行发邮件。

## 脚本内置合并规则（已验证，勿改动）

- 封面/尾页取模板第 4/23 页，封面自动替换 `IPXXXX`→项目ID、`202X.XX.XX`→汇报日期。
- 模板查找顺序：① 项目根目录 `PPT模板.pptx`（项目自有模板优先）② preset 目录 `PPT模板-默认.pptx`（公司统一模板兜底）。
- 每份源 PPT **保留首页作部门分隔页**（首页天然带部门名，如"AD的项目进展汇报"）、只去末页；按部门文件夹编号排序。（2026-10-09 按 PM 反馈调整：原"去首尾页"导致合并后无法区分部门）
- 合并结果摘要含 `templateFrom`（用的哪套模板）。

## 环境备注

- 本机 PowerPoint COM 由 WPS 兼容层提供；`InsertFromFile` 保留源格式已实测；`InsertFromFile` 的 Index 语义是"插到第 Index 页之后"。
- WPS 的 COM 在最后一份演示关闭后会自动退出进程——因此页数统计用 python-pptx 在 Scan 阶段完成，Merge 阶段不再逐份打开源文件。
- 清理阶段 Quit 的 RPC 异常必须 try/catch 忽略。
- `<preset根目录>` 默认 `%USERPROFILE%\AI\preset\PM`，部署位置不同以实际为准。
