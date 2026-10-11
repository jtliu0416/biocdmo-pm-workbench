# 集成边界与实施顺序

## 当前状态

本项目当前是可验证的 preset 原型，manifest 声明了业务工具名，但这些名字不是已经注册的 DSH Service。目标企业系统已明确为：阿里企业邮箱（外部客户邮件）、钉钉（内部沟通）和自研项目管理系统（项目 Timeline）；当前尚未配置这些系统的连接。

## 推荐顺序

1. **本地只读 fixture**：用 JSON/Markdown 验证数据模型和工作流。
2. **文件只读适配器**：接入项目文件夹，提取来源、版本和文本。
3. **Excel 只读适配器**：读取 timeline/action tracker，保留工作表和行号来源。
4. **Outlook/Teams 只读适配器**：读取项目相关邮件和会议记录，默认只生成草稿。
5. **受控写入**：写回项目记录时使用幂等 ID、版本号和审计记录。
6. **外部副作用**：最后才接入发送邮件、建会议和 Teams 发帖。

## 开发前检查

开发 DSH 插件前必须：

- 使用 `cordis_inspect_list` 获取当前 Provider 清单。
- 使用 `cordis_inspect_query` 查询精确的 Service、Event、Config、Tool 或 Slot contract。
- 不根据文档猜 Service 名称、方法名或 schema。
- 将外部系统 ID 与内部 Project/Action/Document ID 建立可追溯映射。
- 先实现只读和 dry-run，再实现写入。

## 数据安全

- 真实客户、分子、合同、质量事件数据不能直接放入示例目录。
- 样例应使用虚构客户和分子。
- 合同、偏差、OOS、CAPA、放行等信息应标记 restricted，并遵循公司权限。
