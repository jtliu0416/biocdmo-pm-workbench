# Encrypt one Office file with the project's fixed password (Office native
# open-password via COM automation). The source file is kept; output is a new
# "-加密" copy unless -OutputPath is given.
# Password lifecycle: set once per project via set-project-password.ps1 in a
# visible console; stored DPAPI-encrypted (CurrentUser) under %APPDATA%.
# The password never appears in chat transcripts or script output, and this
# script never prompts (a hidden agent shell cannot show or answer dialogs).
param(
  [Parameter(Mandatory = $true)][string]$Path,
  [Parameter(Mandatory = $true)][string]$Project,
  [string]$OutputPath
)
$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.Security

$storeDir = Join-Path $env:APPDATA 'pm-workbench'
New-Item -ItemType Directory -Force -Path $storeDir | Out-Null
$storePath = Join-Path $storeDir 'passwords.json'
$store = if (Test-Path -LiteralPath $storePath) { Get-Content -LiteralPath $storePath -Raw -Encoding utf8 | ConvertFrom-Json } else { [pscustomobject]@{} }

function Get-ProjectPassword {
  param([string]$ProjectId)
  $entry = $store.$ProjectId
  if ($entry) {
    $bytes = [System.Security.Cryptography.ProtectedData]::Unprotect([Convert]::FromBase64String([string]$entry), $null, [System.Security.Cryptography.DataProtectionScope]::CurrentUser)
    return [Text.Encoding]::UTF8.GetString($bytes)
  }
  # Fall back to the project folder on the file server: <root>\<ProjectId>\.pm-password
  $projPwdFile = Join-Path ('\\C-FILESERVER\06-项目管理部\01-Project-Ongoing\' + $ProjectId) '.pm-password'
  if (Test-Path -LiteralPath $projPwdFile) {
    return (Get-Content -LiteralPath $projPwdFile -Raw).Trim()
  }
  # Never prompt from an agent-run hidden shell: a GUI dialog hangs forever there.
  throw "项目 $ProjectId 尚未设置密码。请在项目目录 \\C-FILESERVER\06-项目管理部\01-Project-Ongoing\$ProjectId 下创建隐藏文件 .pm-password（内容为密码），或在本机运行 set-project-password.ps1 设置。"
}

# Use ProviderPath: Resolve-Path .Path prefixes UNC paths with "Microsoft.PowerShell.Core\FileSystem::" which Office COM cannot open
$source = (Resolve-Path -LiteralPath $Path -ErrorAction Stop).ProviderPath
$ext = [IO.Path]::GetExtension($source).ToLower()
if ($ext -notmatch '^\.(xlsx|xlsm|xls|docx|docm|doc|pptx|pptm|ppt)$') { throw "不支持的文件类型：$ext（支持 .xlsx/.xlsm/.xls/.docx/.docm/.doc/.pptx/.pptm/.ppt）" }
if (-not $OutputPath) {
  $dir = Split-Path -Parent $source
  $name = [IO.Path]::GetFileNameWithoutExtension($source)
  $OutputPath = Join-Path $dir ($name + '-加密' + $ext)
}
if ((Resolve-Path -LiteralPath $OutputPath -ErrorAction SilentlyContinue).Path -eq $source) { throw '输出路径不能与原文件相同。' }
$password = Get-ProjectPassword -ProjectId $Project

$excel = $null; $word = $null; $ppt = $null
$workbook = $null; $document = $null; $presentation = $null
try {
  switch -Regex ($ext) {
    '^\.xls' {
      $excel = New-Object -ComObject Excel.Application
      $excel.DisplayAlerts = $false
      $workbook = $excel.Workbooks.Open($source)
      $format = if ($ext -eq '.xls') { 56 } elseif ($ext -eq '.xlsm') { 52 } else { 51 }
      $workbook.SaveAs($OutputPath, $format, $password)
    }
    '^\.doc' {
      $word = New-Object -ComObject Word.Application
      $word.DisplayAlerts = 0
      $word.Visible = $false
      $document = $word.Documents.Open($source)
      $format = if ($ext -eq '.doc') { 0 } elseif ($ext -eq '.docm') { 13 } else { 12 }
      # SaveAs with [ref] args: compatible with Word 2007 (12.0); SaveAs2 requires Word 2010+
      $document.SaveAs([ref]$OutputPath, [ref]$format, [ref]$false, [ref]$password)
    }
    '^\.ppt' {
      $ppt = New-Object -ComObject PowerPoint.Application
      $presentation = $ppt.Presentations.Open($source, -1, 0, 0)
      $presentation.Password = $password
      $presentation.SaveAs($OutputPath)
    }
  }
}
finally {
  # Word 2007 throws a harmless RPC error on Quit(); ignore cleanup failures.
  foreach ($cleanup in @(
      { if ($workbook) { $workbook.Close($false) } },
      { if ($excel) { $excel.Quit() } },
      { if ($document) { $document.Close($false) } },
      { if ($word) { $word.Quit() } },
      { if ($presentation) { $presentation.Close() } },
      { foreach ($release in @($presentation, $ppt, $document, $word, $workbook, $excel)) {
          if ($release) { [void][Runtime.InteropServices.Marshal]::ReleaseComObject($release) }
        } }
    )) {
    try { & $cleanup } catch { }
  }
}
if (-not (Test-Path -LiteralPath $OutputPath)) { throw '加密后未找到输出文件，请检查 Office 是否弹出了对话框。' }
Write-Output "OK 已生成加密副本：$OutputPath"
Write-Output "原文件保留未改动：$source"
Write-Output "密码：已用项目 $Project 的固定密码（DPAPI 本机保存，未在输出中显示）。"
