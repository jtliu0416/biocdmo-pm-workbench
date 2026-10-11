---
name: file-encryption
description: "Use when the PM asks to encrypt an Office file (加密/Encrypt) in a BioCDMO project (e.g. xlsx/docx/pptx). Runs pm-workbench encrypt-office.ps1 with the project's fixed password to produce a '-加密' copy."
---

# 项目文件加密（Office 原生密码）

## 用途

PM 要求加密项目文件（"给这份文件加密"、"🔒 加密此文件"按钮）。生成 Office 原生打开密码的 `-加密` 副本，保留原文件。

## 执行步骤

1. 从文件路径识别项目 ID（如 `IP266`）。**禁止在工作区、网盘或本机目录搜索脚本或密码文件**（脚本不在 Workspace 内，搜索必然失败）。
2. 直接运行（`<preset根目录>` 默认 `%USERPROFILE%\AI\preset\PM`，部署位置不同以实际为准）：

   ```
   pwsh -File "<preset根目录>\pm-workbench\encrypt-office.ps1" -Path "<文件路径>" -Project "<项目ID>"
   ```

3. 成功后只回复生成的 `-加密` 副本路径；不回显密码。

## 密码规则（安全红线）

- 密码按项目存放于项目根目录隐藏文件：`\\C-FILESERVER\06-项目管理部\01-Project-Ongoing\<项目ID>\.pm-password`（明文、Hidden 属性，PM 已确认此方案）。
- 脚本读取顺序：① 本机 `%APPDATA%\pm-workbench\passwords.json`（DPAPI，兼容旧设置）② 项目目录 `.pm-password`。
- **首次加密某项目（两处均无密码）**：脚本会报"尚未设置密码"。此时在对话中**提醒 PM 输入该项目密码**；收到后写入项目目录 `.pm-password`（`Set-Content -NoNewline`，设为 Hidden），然后重新运行加密命令。仅需一次，之后全自动。
- 每个项目密码独立互不串用；密码不写入聊天之外的文件，不在后续回复中重复显示。

## 运行环境坑（脚本已修复，勿回退）

- Office COM 路径必须用 `Resolve-Path` 的 `ProviderPath`（`.Path` 对 UNC 带 `FileSystem::` 前缀会导致 RPC 失败）。
- 本机 Word 2007 不支持 `SaveAs2`，用 `SaveAs([ref]...)`。
- 清理阶段 Quit 的 RPC 异常是无害错误，必须 try/catch 忽略。
- Agent 隐藏会话中绝不能用无密码尝试打开加密文件（会在 PM 桌面弹出密码框并挂起）。
