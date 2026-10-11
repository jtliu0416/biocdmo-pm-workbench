# PM Harness 命令目录

这些命令由 `preset/manifest.json` 暴露。当前为 preset-only，输出草稿和分析结果，不执行外部发送或写回。

| 命令 | 用途 | 主要输入 | 主要输出 |
|---|---|---|---|
| `/new-project` | 建立项目档案 | 客户、项目、阶段、日期、里程碑、文件 | 项目摘要、初始 Timeline、Action/Risk register |
| `/meeting-minutes` | 会议记录结构化 | 会议转写/笔记、项目 ID、参会人 | 内部纪要、客户纪要、行动项、风险、邮件草稿 |
| `/weekly-review` | 周度项目控制 | 当前项目记录、会议和文件 | RAG 状态、关键路径、延期、客户依赖、周报 |

## 通用输出规则

- 生成前先列出输入来源。
- 日期、负责人、状态和承诺不能凭空补全。
- 缺失值使用 `TBD` 或 `Needs Confirmation`。
- 客户输出与内部输出分离。
- 涉及客户承诺、延期、质量、合同、价格或放行时附加 `PM Review Required`。
