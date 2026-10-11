# 合并各部门项目进展 PPT 为一份完整汇报。
# 用法（Agent 编排，PM 只发对话指令）：
#   扫描候选: merge-ppt.ps1 -Action Scan  -Project IP266 [-Days 3]
#   执行合并: merge-ppt.ps1 -Action Merge -Project IP266 -ListPath <scan输出的json> [-OutputPath <路径>] [-ReportDate yyyy.M.d] [-Force]
# 规则（PM 已确认）：
#   - 只扫 01-* ~ 12-* 部门文件夹（00-SUM 是输出目录，排除）；每部门只取修改时间最新的一份 .pptx
#   - 每份源 PPT 保留首页（部门分隔页，天然带部门名）、去末页；页数<2 跳过（2026-10-09 按 PM 反馈调整，原为去首尾页）
#   - 封面=PPT模板.pptx 第4页（IPXXXX→项目ID、202X.XX.XX→汇报日期）；尾页=第23页
#   - 输出默认 00-SUM\<项目ID>-项目进展汇报-合并-<yyyy.M.d>.pptx；已存在需 -Force 覆盖（须先经 PM 确认）
# 运行环境备注：Office COM 路径必须用纯 UNC（Resolve-Path 用 ProviderPath）；本机 PowerPoint COM 由 WPS 兼容层提供，
#   InsertFromFile 保留源格式已实测；清理阶段 Quit 的 RPC 异常为 Word/PP 常见无害错误，必须 try/catch 忽略。
param(
  [Parameter(Mandatory = $true)][string]$Project,
  [Parameter(Mandatory = $true)][ValidateSet('Scan', 'Merge')][string]$Action,
  [int]$Days = 3,
  [string]$ListPath,
  [string]$OutputPath,
  [string]$ReportDate,
  [string]$PythonPath,
  [switch]$Force
)
$ErrorActionPreference = 'Stop'
[Console]::OutputEncoding = [Text.UTF8Encoding]::new($false)
Add-Type -AssemblyName System.Web

$root = '\\C-FILESERVER\06-项目管理部\01-Project-Ongoing\' + $Project + '\05-项目进展汇报'
if (-not (Test-Path -LiteralPath $root)) { throw "目录不存在：$root" }
$script:warnings = New-Object System.Collections.Generic.List[string]

# 只读统计 pptx 页数（python-pptx）；失败返回 -1 并记录警告
# python 解释器自动探测（可移植）：① 可选参数 -PythonPath ② DSH 运行时（按当前用户名解析）③ PATH 上的 python
$script:PythonExe = $PythonPath
if (-not $script:PythonExe) {
  $cands = @(
    (Join-Path $env:USERPROFILE '.dsh\dsh-runtimes\dsh-primary-runtime\dependencies\python\python.exe'),
    (Get-Command python -ErrorAction SilentlyContinue | Select-Object -ExpandProperty Source -ErrorAction SilentlyContinue)
  ) | Where-Object { $_ -and (Test-Path $_) }
  $script:PythonExe = $cands | Select-Object -First 1
}
function Get-PptxSlideCount {
  param([string]$Path)
  if (-not $script:PythonExe) { $script:warnings.Add("未找到 python（可用 -PythonPath 指定），无法统计页数：$Path"); return -1 }
  try {
    $n = & $script:PythonExe -c "import sys;from pptx import Presentation;print(len(Presentation(sys.argv[1]).slides))" $Path 2>$null
    return [int]($n | Select-Object -Last 1)
  } catch { $script:warnings.Add("统计页数失败：$Path"); return -1 }
}

if ($Action -eq 'Scan') {
  $cutoff = (Get-Date).AddDays(-$Days)
  $deptDirs = Get-ChildItem -LiteralPath $root -Directory |
    Where-Object { $_.Name -match '^\d{2}-' -and [int]($_.Name.Substring(0, 2)) -ge 1 } |
    Sort-Object { [int]($_.Name.Substring(0, 2)) }
  $candidates = New-Object System.Collections.Generic.List[object]
  $dropped = New-Object System.Collections.Generic.List[object]
  foreach ($d in $deptDirs) {
    $files = Get-ChildItem -LiteralPath $d.FullName -Filter '*.pptx' -File |
      Where-Object { $_.LastWriteTime -ge $cutoff } |
      Sort-Object LastWriteTime -Descending
    if (-not $files) { continue }
    $latest = $files[0]
    $candidates.Add([pscustomobject]@{
        dept      = $d.Name
        path      = $latest.FullName
        lastWrite = $latest.LastWriteTime.ToString('yyyy-MM-dd HH:mm:ss')
        slides    = (Get-PptxSlideCount -Path $latest.FullName)
      })
    foreach ($old in ($files | Select-Object -Skip 1)) {
      $dropped.Add([pscustomobject]@{
          dept      = $d.Name
          path      = $old.FullName
          lastWrite = $old.LastWriteTime.ToString('yyyy-MM-dd HH:mm:ss')
        })
    }
  }
  if ($candidates.Count -eq 0) { $script:warnings.Add("近 $Days 天各部门文件夹无 PPT 更新") }
  [pscustomobject]@{
    project    = $Project
    days       = $Days
    candidates = $candidates
    dropped    = $dropped
    warnings   = $script:warnings
  } | ConvertTo-Json -Depth 4
  return
}

# ---------- Merge ----------
if (-not $ListPath) { throw 'Merge 需要 -ListPath（Scan 输出的 JSON 文件）' }
$list = (Get-Content -LiteralPath $ListPath -Raw -Encoding utf8 | ConvertFrom-Json).candidates
if (-not $list -or @($list).Count -eq 0) { throw '清单为空，无内容可合并' }
$list = @($list | Sort-Object { [int]($_.dept.Substring(0, 2)) })

if (-not $OutputPath) {
  $OutputPath = Join-Path (Join-Path $root '00-SUM') ("{0}-项目进展汇报-合并-{1}.pptx" -f $Project, (Get-Date).ToString('yyyy.M.d'))
}
if ((Test-Path -LiteralPath $OutputPath) -and -not $Force) { throw "输出文件已存在，需 PM 确认后加 -Force 覆盖：$OutputPath" }

# 模板查找顺序：① 项目根目录 PPT模板.pptx（项目自有模板优先）② preset 默认模板（公司统一模板）
# 用 $PSScriptRoot 定位 preset，保证移植到其他 PM 机器后无需改路径
$template = Join-Path $root 'PPT模板.pptx'
$templateFrom = '项目根目录'
if (-not (Test-Path -LiteralPath $template)) {
  $template = Join-Path $PSScriptRoot 'PPT模板-默认.pptx'
  $templateFrom = 'preset 默认模板'
  if (-not (Test-Path -LiteralPath $template)) { throw "项目目录与 preset 中均未找到模板（期望：$(Join-Path $root 'PPT模板.pptx') 或 $template）" }
}
Copy-Item -LiteralPath $template -Destination $OutputPath -Force
if (-not $ReportDate) { $ReportDate = (Get-Date).ToString('yyyy.M.d') }

$skipped = New-Object System.Collections.Generic.List[object]
# 页数直接用清单里的 slides（python-pptx 只读统计）：
# 不要用 COM 逐份打开源文件数页——WPS 的 PowerPoint COM 在最后一份演示关闭后会自动退出进程，导致后续调用失效
$valid = New-Object System.Collections.Generic.List[object]
foreach ($item in $list) {
  if (-not (Test-Path -LiteralPath $item.path)) { $skipped.Add([pscustomobject]@{ path = $item.path; reason = '文件不存在' }); continue }
  $n = [int]$item.slides
  if ($n -lt 0) { $n = Get-PptxSlideCount -Path $item.path }
  if ($n -lt 2) { $skipped.Add([pscustomobject]@{ path = $item.path; reason = "仅 $n 页（需>=2，去末页后无内容）" }); continue }
  $valid.Add([pscustomobject]@{ path = $item.path; dept = $item.dept; slides = $n })
}
if ($valid.Count -eq 0) { throw '没有可合并的有效 PPT' }

$pp = $null; $deck = $null
try {
  $pp = New-Object -ComObject PowerPoint.Application
  $deck = $pp.Presentations.Open(((Resolve-Path -LiteralPath $OutputPath).ProviderPath), 0, 0, $false)
  # 1) 删除模板第1-3页（保留第4页为封面），再删除第5-22页（保留原23页为尾页）
  foreach ($idx in 3..1) { $deck.Slides.Item($idx).Delete() }
  # 原第5-22页现在位于第2~19位（封面=1，尾页=20）
  foreach ($idx in 19..2) { $deck.Slides.Item($idx).Delete() }
  if ($deck.Slides.Count -ne 2) { throw "模板裁剪异常，当前页数：$($deck.Slides.Count)（应为2）" }
  # 2) 封面占位替换
  $cover = $deck.Slides.Item(1)
  foreach ($shape in $cover.Shapes) {
    if ($shape.HasTextFrame -eq -1) {
      try { [void]$shape.TextFrame.TextRange.Replace('IPXXXX', $Project) } catch { }
      try { [void]$shape.TextFrame.TextRange.Replace('202X.XX.XX', $ReportDate) } catch { }
    }
  }
  # 3) 逐份插入：保留首页作部门分隔页（首页天然带部门名，如"AD的项目进展汇报"），只去末页
  #    （2026-10-09 按 PM 反馈调整：原"去首尾页"会把部门标题页去掉，合并后无法区分部门）
  #    InsertFromFile 的 Index 语义是"插到第 Index 页之后"，故用 Count-1 保证内容始终插在尾页之前
  $inserted = 0; $totalSlides = 2
  foreach ($item in $valid) {
    $pos = $deck.Slides.Count - 1
    [void]$deck.Slides.InsertFromFile($item.path, $pos, 1, $item.slides - 1)
    $inserted++; $totalSlides += ($item.slides - 1)
  }
  [void]$deck.Save()
  $finalSlides = $deck.Slides.Count
}
finally {
  foreach ($cleanup in @(
      { if ($deck) { $deck.Close() } },
      { if ($pp) { $pp.Quit() } }
    )) {
    try { & $cleanup } catch { }
  }
}
if (-not (Test-Path -LiteralPath $OutputPath)) { throw '合并后未找到输出文件' }
[pscustomobject]@{
  output      = $OutputPath
  merged      = $inserted
  totalSlides = $finalSlides
  skipped     = $skipped
  coverFixed  = $true
  templateFrom = $templateFrom
  warnings    = $script:warnings
} | ConvertTo-Json -Depth 4