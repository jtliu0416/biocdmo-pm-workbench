# BioCDMO PM Workbench（AI PM 工作台）

面向生物药 CDMO 项目经理的 **DSH（DeepSeek Harness）AI 工作台预设**：把钉钉 AI 听记、项目文件、文档交付物接进 DSH，形成一套可日常使用、可分发、有守卫防回退的 PM 工作环境。

> 📘 **改代码前必读**：[开发教训与架构约定](docs/pm-workbench-dev-lessons.md)
> 📦 **装到别的机器 / 别的 PM**：[分发与配置文档](docs/pm-workbench-deployment.md)

## 产品定位

不是单纯的写作助手，而是项目事实、承诺、时间线、行动项、风险和客户沟通的统一工作台。

核心链路：

```text
文件 / 邮件 / 会议记录（钉钉 AI 听记）
        ↓
项目事实库（.pm-cache + 项目盘归档）
        ↓
Timeline / Action / Risk / Contract
        ↓
周报 / 会议纪要 / 客户邮件 / 管理层报告
```

MVP 路线：① 项目档案与状态总览 ② 会议纪要 → 行动项与风险 ✅ ③ 时间线检查 ④ 项目周报 ⑤ 客户邮件草稿。

## 功能总览

### 📅 会议纪要面板（右侧栏标签）✅ 已交付

浏览钉钉 AI 听记（按 今天/本周/更早 分组 + 搜索），四步闭环：

| 操作 | 说明 | 需要 AI |
|---|---|---|
| 点标题 | 内置浏览器打开钉钉听记原页 | 否 |
| 点 `▸` | 面板内看摘要 / 行动项 / 关键词 / 转写 | 否 |
| `🔄 同步` | 从钉钉拉取最新听记到本地缓存（首次=自动生成缓存） | 是（Agent 执行 dws） |
| `📥 归档` | 运行归档脚本，产出 01~06 编号文件包到项目盘 | 是（Agent 执行脚本） |
| `📂 打开` | 原生文件树 + 资源管理器定位归档目录 | 否 |
| `⟳` | 纯本地重读缓存 | 否 |

**归档包结构**（`<项目根>\06-项目会会议纪要\<项目ID>-<日期>-<标题>\`）：
`01 会议纪要 docx+md` · `02 录音` · `03 AI摘要` · `04 行动项 csv` · `05 逐字稿` · `06 关键词`

**归档状态**：按当前工作区项目判定（🟢 本项目已归档 / 🟡 已归档于其他项目）；索引键 = `uuid+项目`，同一听记可归档到多个项目。

### 📎 文件引用（默认关闭）
自研"引用到对话"按钮已由 better-sidebar / DSH 原生 `@` 引用覆盖，默认关闭（`client.js` 顶部 `ENABLE_FILE_REFERENCE` 开关可恢复）。

### 🔒 文件加密（技能）✅ 已交付
`@` 引用文件后说"加密这份文件"→ 运行 `encrypt-office.ps1`，Office 原生密码生成 `-加密` 副本；密码按项目存放于项目根 `.pm-password`（不回显）。

### 📊 PPT 合并（技能）✅ 已交付
说"合并近 N 天的 PPT"→ `merge-ppt.ps1`（Scan 出候选 → PM 确认 → Merge），按部门编号合并，模板封面/尾页，输出到 `00-SUM`。

## 目录结构

```text
pm-workbench\        会议纪要面板（client.js）+ 归档脚本 + 配置（projects.json）+ 守卫
dsh-preset\          DSH profile 补丁（系统提示 / agent 预设 / skills 注册）
preset\              系统提示词、manifest、集成设计文档
skills\              file-encryption / ppt-merge（部署到 %USERPROFILE%\.agents\skills\）
workflows\           meeting-minutes / new-project / weekly-review
docs\                dev-lessons（教训，必读）· deployment（分发，必读）· 设计文档
templates\ knowledge\ examples\   模板 / 领域知识 / 示例
```

## 快速开始（分发到新机器）

详见 [docs/pm-workbench-deployment.md](docs/pm-workbench-deployment.md)。简版：

```powershell
# 1. 装 DSH 桌面版 + dws 并登录
npm i -g dingtalk-workspace-cli ; dws auth login
# 2. 装 better-sidebar（版本锁定 0.25.0）+ link 本仓库两个包进 DSH profile
#    （详见 deployment 文档 §3，含完整命令）
# 3. 编辑 pm-workbench\projects.json 填项目根 → 重启 DSH 一次
# 4. 面板点「🔄 同步」生成缓存 → 完成
```

**环境切换**（测试 ⇄ 生产）：只改 `pm-workbench\projects.json` 的 `file_root`（当前生产 = `G:\06-项目管理部-宋莉\01-Project-Ongoing\<项目ID>`；`G:` 是 `\\intbio.com\group` 的映射盘）。

## 验收守卫（每次改动后必须全绿）

```powershell
pwsh -File pm-workbench\verify.ps1        # 架构守卫 + 可移植性守卫 + 索引边界校验 + 文档存在性
node pm-workbench\verify-client.cjs       # 客户端行为测试
```

守卫会拦截：宿主路由复活（历史上导致反复 404 的根源）、`name`/`inject` 导出（导致 apply 不被调用）、个人路径硬编码、教训/分发文档缺失。

## 使用原则（Agent 行为红线）

- 区分事实、推断和建议，并保留信息来源；不擅自承诺客户日期、价格、质量结论或合同解释。
- 客户版输出客观、专业、可追溯，标 `PM Review Required`；内部版可直接暴露阻塞和升级建议。
- 对延期、偏差、OOS、CAPA、合同及客户承诺标记人工审核。
- 项目归属取自当前会话工作区；归档/分析等确定性操作走脚本，不经 AI 转述。

## 已知边界

- 新听记需点 `🔄 同步` 才会进面板（拉取钉钉需运行 dws，见架构说明）
- Word 不支持侧栏内联预览 → 归档包含 `.md` 阅读版
- 企业空间听记的详情/录音需管理员开通"组织内使用"，否则面板显示读取失败
