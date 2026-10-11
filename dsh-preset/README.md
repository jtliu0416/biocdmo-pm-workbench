# 在 DeepSeek Harness GUI 中启用 BioCDMO PM Harness

## 已创建

`biocdmo-pm-harness.patch.yml` 是基于 DSH 内置 `standard` preset 复制并修改后的 YAML 声明。

它保持 Standard preset 的工具和运行能力，并将 persona 改为 BioCDMO PM Harness：

- 使用已批准 Timeline 作为日期和里程碑状态的主来源。
- 区分事实、推断和建议，并保留来源。
- 区分 Risk / Issue / Change。
- 客户版与内部版分离。
- 涉及延期、质量、合同、价格、批次放行或法规结论的草稿添加 `PM Review Required`。
- 仅生成草稿；不自动发送阿里企业邮箱邮件、不自动发钉钉、不修改 Timeline。

## 可安装 Bundle

本目录现在是一个符合 DSH bundle 约定的本地包：

- `package.json`：声明 `dsh.bundle.patch`。
- `cordis.patch.yml`：真正由 bundle 安装流程加载的 preset 声明。
- `biocdmo-pm-harness.patch.yml`：同一声明的工作区副本，便于审阅。

Preset identity：`biocdmo-pm-harness`  
展示名：`BioCDMO PM Harness`

## 安装到当前 DSH Profile

使用 DSH Plugin Manager 安装本地 bundle，目标目录为：

```text
C:\Users\jintao.liu\AI\preset\PM\dsh-preset
```

安装后通过 Plugin Manager 的 `list_bundles` 确认 bundle 存在，并通过 `list_plugins` 确认 `preset-biocdmo-pm-harness` 处于 active。DSH 会立即应用 live profile 的 bundle；若 GUI 未显示新选项，再完全重启应用。

> 旧的 Profile patch 副本仅作为之前尝试的配置记录。最终应以已安装的本地 bundle 为加载来源，避免重复声明。

## 在 GUI 中加载

1. 如刚安装完成但 GUI 没有更新，**完全退出并重新打开 DeepSeek Harness**。
2. 新建一个**空白会话**。
3. 在会话创建前的 preset 下拉菜单中选择 **BioCDMO PM Harness**。
4. 在新会话中输入项目材料或上传文件，然后使用：
   - `/new-project`
   - `/meeting-minutes`
   - `/weekly-review`

Preset 选择仅能在会话首次提交前完成；已有会话不会自动切换到新 preset。

## 验收提示

新会话的回答应体现以下行为：

- 明确标注事实来源和待确认信息；
- 不擅自承诺客户日期；
- 对高风险客户邮件标记 `PM Review Required`；
- 将自研项目管理系统的 approved Timeline 视为计划日期主数据；
- 将阿里企业邮箱用作客户沟通证据、钉钉用作内部协作证据，而不直接发送或写入。

## 业务资产

业务 prompt、模型、工作流与集成方案仍在工作区的 `preset/`、`workflows/`、`knowledge/` 和 `templates/` 目录中。当前 GUI preset 把关键规则压缩到 persona 中；未来如需把完整 Markdown 资产动态注入，需要额外实现本地 DSH plugin 或 skill provider。
