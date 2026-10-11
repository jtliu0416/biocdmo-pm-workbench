# 示例端到端验证 Runbook

## 目标

验证 `sample-project.json` + `sample-meeting.txt` 是否能产出可追溯的会议纪要、行动项、风险、周报和客户邮件草稿。

## 手工运行步骤

1. 读取 `sample-project.json`，建立当前项目基线。
2. 读取 `sample-meeting.txt`，按 `workflows/meeting-minutes.md` 分类事实、决定、行动项、风险和待确认事项。
3. 与既有项目记录去重：会议中的“确认样品运输温度和数量”应更新既有 ACT-001，而不是新建重复事项。
4. 保留新增的 follow-up meeting 行动项；具体日期未知时使用 `TBD`。
5. 按 `preset/status-rules.md` 评估状态：项目为 Amber，不得直接升级为 Red，因为最终延期尚未确认。
6. 按 `workflows/weekly-review.md` 生成周报，并根据 `preset/system-prompt.md` 增加来源和 `PM Review Required`。

## 预期产物

- `output/internal-meeting-minutes.md`
- `output/client-meeting-minutes.md`
- `output/weekly-review.md`
- `output/client-follow-up-email.md`
- `output/timeline-check.json`
- `output/action-query.json`
- `output/project-search.json`

## 验收清单

- [x] 明确列出 2025-04-15 客户确认事项
- [x] 明确列出 2025-04-17 分析方法文件清单
- [x] 明确列出 2025-04-18 样品到货
- [x] 明确列出 2025-04-25 差距分析及其依赖
- [x] 识别样品运输信息为 Medium/High 风险
- [x] 客户版没有内部归责描述
- [x] 未知 follow-up meeting 日期标记为 TBD
- [x] 客户邮件包含 PM Review Required
- [x] 所有关键结论包含来源或明确假设
