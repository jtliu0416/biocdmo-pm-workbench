# 原生右侧“项目文件”接入：技术结论与实施路径

## 用户目标

在当前 DSH 中复用现有的 **工作区文件** 右侧栏，而不是再绘制一个项目目录树：右栏被打开后，根目录就是当前项目的 UNC 文件根目录。

```text
当前会话
  └─ 原生右侧栏 / 工作区文件
      └─ \\intbio.com\group\06-项目管理部-宋莉\01-Project-Ongoing\IP160
```

## 已确认的 DSH 原生约束

内置 `@deepseek-ai/dsh-client-ui-sidebar-files`：

1. 完整负责原生的目录树、展开/收起、刷新、文件资源打开和右栏预览链路；
2. 其目录树根固定读取当前 `Session.cwd`；
3. 目录列举使用 `workspaceFiles.list(sessionId, path)`；Host 严格限制目录必须仍在该 Session 的 workspace root 内；
4. 普通文件预览可以读取当前 Session workspace 之外的绝对路径，但目录树**不能**越过 workspace root；
5. 现有对话的 `Session.cwd` 是创建 Session 时写入 Header 的不可变工作目录，不能安全地在项目切换时直接改为 UNC 项目根。

因此，不能安全地通过“给现有对话的工作区文件树换根”来实现项目挂载；那会要求改写当前会话不可变工作目录，或绕过 `workspaceFiles` 的目录沙箱。

## 推荐实现：Project File Workspace（原生 Files，不绕过安全边界）

每个明确授权项目创建或复用一个 DSH Workspace / Session：

```text
Workspace: PM-IP160
workspace cwd: \\intbio.com\group\06-项目管理部-宋莉\01-Project-Ongoing\IP160
Session: PM Files · IP160
```

进入该项目文件会话后，点击内置 `工作区文件`：

- 显示真正的原生文件树，而不是自定义树；
- 根目录为该项目 UNC 根；
- 点击文件继续走内置 Document Preview / Office-to-PDF 链路；
- 内置 Remote 本身不提供写接口；
- 根目录由明确 `projects.json` allowlist 提供，不能输入任意 UNC 路径。

### 与 PM 对话的衔接

当前 PM 对话保留项目上下文条：

```text
项目：IP160 · 只读 · [打开 IP160 项目文件]
```

点击它：

1. 打开 / 聚焦 `PM Files · IP160` 会话；
2. 右侧原生工作区文件树显示 IP160；
3. 文件预览在该文件会话的右栏中打开；
4. 后续“加入对话上下文”必须由明确的受控单文件引用动作连接回原 PM 对话，不隐式复制文件正文。

## 备选实现：自定义 Project Files Remote

如果产品要求“在完全同一个对话 Session 的右栏内显示任意项目 UNC 根”，需要新增一个 `pmProjectFiles` Host Remote：

```text
list(projectId, relativePath)
stat(projectId, relativePath)
read(projectId, relativePath)
changes(projectId, relativePath)
```

并重用 / 提取内置 Files Tree UI。它需要额外的类型协议、Remote Gateway 装配、文件资源 Provider 与 Document Preview 授权模型，不能把 Client 的静态 JSON 或任意绝对 UNC 路径直接暴露出去。

这个方案能实现“同一对话右栏”，但实现量显著更大；应在先验证 Project File Workspace 的原生体验后再进行。

## 严格安全规则

- 仅允许 `IP266`、`IP322`、`IP160`。
- `project_id → UNC root` 仅来自 `projects.json` / 后续 PMS MCP；不可由 UI 自由输入。
- 不允许路径包含 `..` 或绝对路径逃逸。
- 不创建、修改、删除、移动、重命名或上传文件。
- 不自动读取文件正文、不自动纳入 PM 对话。
- 项目会话的文件浏览和原 PM 对话的模型上下文始终显式分离。
