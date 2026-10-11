# 只读工具契约（MVP 示例）

这些是 preset 层的业务契约草案，不代表当前运行时已经注册了同名 Service 或 Tool。

## `timeline_check`

### 输入

```json
{"project":"BioCDMO PM Project","as_of":"YYYY-MM-DD","delay_scenario_days":0}
```

### 输出

```json
{"project_id":"string","overall_status":"Green | Amber | Red","at_risk_milestones":[],"overdue_actions":[],"missing_fields":[],"critical_path":[],"scenario_impacts":[],"sources":[]}
```

### 规则

- 只读，不修改项目文件。
- 以 `as_of` 为判断基准；不使用隐含的当前日期。
- 不把 `At Risk` 自动解释成已延期。
- 依赖未完成或日期未知时，列出影响和假设。
- `delay_scenario_days` 只用于情景分析，不能覆盖原计划日期。

## `action_query`

### 输入

```json
{"project":"BioCDMO PM Project","as_of":"YYYY-MM-DD","filter":"all | overdue | due_soon | client_owned | unassigned","days_ahead":7}
```

### 输出

```json
{"project_id":"string","as_of":"YYYY-MM-DD","filter":"string","actions":[],"counts":{"total":0,"overdue":0,"due_soon":0,"client_owned":0,"unassigned":0},"sources":[]}
```

### 规则

- 只读，不发送催办邮件、不改写状态、不改变截止日期。
- `overdue` 只包含截止日期早于 `as_of` 且未 Done/Cancelled 的行动项。
- `due_soon` 包含从 `as_of` 起未来 `days_ahead` 天内到期的开放行动项。
- `client_owned` 根据 `owner_type=Client` 判断；不能根据姓名猜测。
- 缺少 owner 的行动项进入 `unassigned`；不得自动分配给 PM。
- 输出需保留 action 的原始来源。

## `project_search`

### 输入

```json
{"project":"BioCDMO PM Project","query":"sample | risk | milestone | contract | owner | date","entity":"all | project | milestone | action | risk | document | contract_obligation"}
```

### 输出

```json
{"project_id":"string","query":"string","entity":"string","matches":[],"sources":[]}
```

### 规则

- 只读，返回项目内部已登记事实，不把推测作为匹配结果。
- 搜索同时覆盖项目字段、里程碑、行动项、风险、文件和合同义务。
- `entity` 用于限制搜索范围；`all` 返回按实体分类的匹配。
- 匹配结果保留实体 ID、字段、简短内容和来源。
- 空查询不应返回全部敏感数据；应要求用户提供项目或查询条件。
