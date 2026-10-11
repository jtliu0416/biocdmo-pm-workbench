# One-time per-project password setup. Run this yourself in a visible
# PowerShell window; the entered password is stored DPAPI-encrypted
# (CurrentUser) under %APPDATA%\pm-workbench\passwords.json.
# Agent-run encryption reads the stored password and never sees or shows it.
param(
  [Parameter(Mandatory = $true)][string]$Project
)
$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.Security

$entered = Read-Host -AsSecureString "请输入项目 $Project 的固定加密密码"
$plain = [Runtime.InteropServices.Marshal]::PtrToStringBSTR(
  [Runtime.InteropServices.Marshal]::SecureStringToBSTR($entered))
if ([string]::IsNullOrWhiteSpace($plain)) { throw '未输入密码，已取消。' }

$storeDir = Join-Path $env:APPDATA 'pm-workbench'
New-Item -ItemType Directory -Force -Path $storeDir | Out-Null
$storePath = Join-Path $storeDir 'passwords.json'
$store = if (Test-Path -LiteralPath $storePath) { Get-Content -LiteralPath $storePath -Raw -Encoding utf8 | ConvertFrom-Json } else { [pscustomobject]@{} }
$protected = [System.Security.Cryptography.ProtectedData]::Protect([Text.Encoding]::UTF8.GetBytes($plain), $null, [System.Security.Cryptography.DataProtectionScope]::CurrentUser)
$store | Add-Member -NotePropertyName $Project -NotePropertyValue ([Convert]::ToBase64String($protected)) -Force
$store | ConvertTo-Json | Set-Content -LiteralPath $storePath -Encoding utf8
Write-Output "OK 项目 $Project 的密码已加密保存到 $storePath"
Write-Output '之后 Agent 运行 encrypt-office.ps1 时会自动使用，无需再输入。'
