# Preset Package

## Entry point

`manifest.json` 是 BioCDMO PM Harness 的 preset 清单，声明角色规则、项目 schema、知识文件、命令和工具分层。

## 当前能力

- 三个命令：`new-project`、`meeting-minutes`、`weekly-review`
- 只读分析优先
- 输出草稿，不执行邮件发送、日历创建或外部写入
- 需要 PM 审阅的高风险内容由 manifest 的 `safety` 字段声明

## 连接策略

当前 `integrationStatus` 为 `preset-only; external adapters not configured`。不要将本清单中的工具名当作已经存在的业务 Service；开发插件时应先查询当前运行时的精确 Service、Event、Config 和 Tool contract。
