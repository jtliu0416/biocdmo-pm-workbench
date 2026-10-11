# 会议纪要面板 M1 实现计划（宿主服务 + 原生侧栏）

> 目标：右侧栏「会议纪要」面板 = 浏览（新→旧列表）→ 点击查看详情 → 一键下载归档到项目盘。全程直连，不经 AI 对话。

**架构**：pm-workbench 插件扩展为双层。
- 宿主层 `index.js`：回环 HTTP 服务（127.0.0.1:8799），3 个端点（list / detail / download），Origin 安全围栏（同 BrowserSkill 模式）；download 端点内部调 dws 拉内容 + 运行时 python(python-docx) 生成 Word 写入项目盘。
- 界面层 `client.js`：原生 tab 的 Body 渲染面板：搜索过滤 + 列表（新→旧，状态徽标）+ 行内展开详情（摘要/行动项/关键词）+ 每条「🌐网页」「📥下载归档」按钮 + 项目选择器（标题未含项目号时）。

**关键规则**
- 归档目录：`\\C-FILESERVER\06-项目管理部\01-Project-Ongoing\<项目>\06-项目会会议纪要\`（不存在则创建）。
- 文件名：`<项目>-会议纪要-<yyyyMMdd>-<标题净化>.docx`；重名加 `-2` 递增。
- 项目识别：标题/uuid 解码文本中匹配 `IP\d{3}`（含 OCUL101→IP266 映射的备注）→ 未匹配则前端弹项目选择（IP266/IP322/IP160）。
- dws 调用：宿主 spawn `dws ... --format json`，20s 超时，失败返回 {error} 由前端展示重试。
- 安全围栏：仅绑定 127.0.0.1；拒绝 Origin 存在且非同宿主；仅 GET。
- 性能护栏沿用（DOM 护栏、观察器节流）。

**任务分解**
1. 宿主服务 `index.js`：HTTP 服务 + list/detail 端点 + 安全围栏 + 端口冲突退避（8799→8809）。
2. 下载归档端点：+detail 拉内容 → python-docx 生成 → 写入项目盘 → 返回路径；附 `pm-minutes-docx.py` 生成脚本。
3. 界面层 `client.js` Body 重写：列表/详情/下载交互 + 样式（对齐原生卡片视觉变量）。
4. 移除旧 DOM 卡片兜底残留 & quick-prompt 按钮合并进面板底部。
5. verify.ps1 正向检查（宿主服务 + 端点关键词）；端到端手测（真实数据 list/detail/download）。
