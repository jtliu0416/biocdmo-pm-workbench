# 发布与接入检查清单

## Preset 原型完成

- [x] 产品定位和 CDMO 生命周期
- [x] PM system prompt 与安全边界
- [x] Project schema、RAG 状态规则
- [x] new-project / meeting-minutes / weekly-review 工作流
- [x] 工具架构与工具契约
- [x] 脱敏示例项目和端到端输出
- [x] timeline-check / action-query / project-search 本地只读示例
- [x] PowerShell 验证脚本

## 接入真实企业系统前

- [x] 确认目标数据源：阿里企业邮箱（客户邮件）、钉钉（内部协作）、自研项目管理系统（Timeline）
- [ ] 确认项目编号、客户、分子、批次和合同数据的访问权限
- [ ] 使用运行时 Inspect 查询精确的 Service/Event/Config/Tool contract
- [ ] 用只读账号或 dry-run 完成最小连接测试
- [ ] 建立外部 ID ↔ 内部实体 ID 映射
- [ ] 定义错误、重试、同步时间和审计策略
- [ ] 由 PM/QA/法务确认高风险内容的人工审阅边界

## 第一版不应自动化

- 未经 PM 审阅发送客户承诺、延期、质量、合同或价格邮件
- 自动修改批准的时间线或合同义务
- 自动关闭风险、问题、偏差或 CAPA
- 自动作出 QA/QC、法务或法规结论
