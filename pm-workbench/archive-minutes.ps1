# 归档一条钉钉听记：建立独立文件夹，按类型编号存放全部产物。
# 用法：pwsh -File archive-minutes.ps1 -Uuid <taskUuid> [-Project IP266] [-Title "会议标题"] [-NoAudio] [-OutputRootOverride <用于测试的根目录>]
# 产物（01~06 编号固定）：
#   01-会议纪要-<标题>.docx   （标题/基本信息/AI摘要/行动项/关键词/转写全文）
#   02-录音-<标题>.mp3        （限时 OSS 链接，需立即下载；-NoAudio 跳过）
#   03-AI摘要-<标题>.md       （钉钉原始 Markdown 摘要）
#   04-行动项-<标题>.csv      （序号,行动项,负责人,截止时间,来源）
#   05-逐字稿-<标题>.md
#   06-关键词-<标题>.md
# 项目号：优先 -Project；否则从标题识别 IPxxx；识别不到时输出 needProject 并由调用方询问 PM。
param(
  [Parameter(Mandatory = $true)][string]$Uuid,
  [string]$Project,
  [string]$Title,
  [switch]$NoAudio,
  [switch]$Force,
  [string]$ProjectRoot = '',
  [string]$SubFolder = '06-项目会会议纪要',
  [string]$OutputRootOverride
)
$ErrorActionPreference = 'Stop'

# 项目根解析（可移植）：参数 -ProjectRoot > 环境变量 PM_PROJECT_ROOT > projects.json（同目录）
if (-not $ProjectRoot) { $ProjectRoot = $env:PM_PROJECT_ROOT }
if (-not $ProjectRoot) {
  try {
    $cfgPath = Join-Path $PSScriptRoot 'projects.json'
    if (Test-Path $cfgPath) {
      $cfg = Get-Content $cfgPath -Raw -Encoding UTF8 | ConvertFrom-Json
      if ($cfg.project_parent) { $ProjectRoot = $cfg.project_parent }
      elseif ($cfg.projects -and $cfg.projects.Count) {
        $first = $cfg.projects[0].file_root -replace '[\\/]+$', ''
        $ProjectRoot = $first.Substring(0, [Math]::Max($first.LastIndexOf('\'), $first.LastIndexOf('/')))
      }
    }
  } catch { }
}
[Console]::OutputEncoding = [Text.UTF8Encoding]::new($false)

function Invoke-Dws([string[]]$DwsArgs) {
  $raw = & dws @DwsArgs --format json 2>$null | Out-String
  if (-not $raw.Trim()) { return $null }
  return ($raw | ConvertFrom-Json)
}
function Unwrap($node) {
  if ($null -eq $node) { return @{} }
  if ($node.PSObject.Properties.Name -contains 'result' -and $node.result) { return $node.result }
  return $node
}
function Sanitize([string]$s) {
  if (-not $s) { return '未命名会议' }
  $x = $s -replace '[\\/:*?"<>|\r\n]+', ' '
  $x = ($x -replace '\s+', ' ').Trim()
  if ($x.Length -gt 60) { $x = $x.Substring(0, 60).Trim() }
  if (-not $x) { return '未命名会议' }
  return $x
}

# 1) 拉取详情
$detail = Invoke-Dws @('minutes', '+detail', '--id', $Uuid)
if (-not $detail) { throw "dws 未返回数据（taskUuid 是否有效？）" }
$basic = Unwrap $detail.basic
$summaryNode = Unwrap $detail.summary
$todosNode = Unwrap $detail.todos
$keywordsNode = Unwrap $detail.keywords
$transcriptNode = Unwrap $detail.transcript

if (-not $Title) { $Title = $basic.title }
$safeTitle = Sanitize $Title

# 2) 项目号
if (-not $Project) {
  if ($Title -match 'IP\s?(\d{3})') { $Project = 'IP' + $Matches[1] }
}
if (-not $Project -and -not $OutputRootOverride) {
  [pscustomobject]@{ needProject = $true; title = $Title; uuid = $Uuid; hint = '内容中无项目号，请 PM 指定项目（IP266/IP322/IP160）' } | ConvertTo-Json -Depth 4
  exit 2
}
if (-not $Project) { $Project = 'TEST' }

# 3) 归档目录
$stamp = if ($basic.startTime) { (Get-Date -Date ([DateTimeOffset]::FromUnixTimeMilliseconds([int64]$basic.startTime).LocalDateTime) -Format 'yyyy.MM.dd') } else { (Get-Date -Format 'yyyy.MM.dd') }
$folderName = "$Project-$stamp-$safeTitle"
if ($OutputRootOverride) { $baseDir = $OutputRootOverride } else { $baseDir = Join-Path (Join-Path $ProjectRoot $Project) $SubFolder }
$dir = Join-Path $baseDir $folderName
# 归档索引（个人）：%USERPROFILE%\.pm-workbench\cache\archive-index.json —— 跟人走，多 PM 零冲突
$indexPath = Join-Path (Join-Path $env:USERPROFILE '.pm-workbench') 'cache\archive-index.json'

# 重复保护：目标文件夹已存在且未指定 -Force 时不重复写入
if ((Test-Path $dir) -and -not $Force) {
  $prev = $null
  if (Test-Path $indexPath) { try { $prev = @((Get-Content $indexPath -Raw -Encoding UTF8 | ConvertFrom-Json).entries | Where-Object { $_.uuid -eq $Uuid -and $_.project -eq $Project }) | Select-Object -First 1 } catch { } }
  # 索引缺失时补种一条（保证面板"已归档"徽标可见）
  if (-not $prev) {
    try {
      $seed = @{ entries = @() }
      if (Test-Path $indexPath) { try { $seed = Get-Content $indexPath -Raw -Encoding UTF8 | ConvertFrom-Json } catch { } }
      $entryList = @($seed.entries | Where-Object { -not ($_.uuid -eq $Uuid -and $_.project -eq $Project) })
      $entryList += [pscustomobject]@{ uuid = $Uuid; title = $Title; project = $Project; folder = $dir; archivedAt = (Get-Date -Format o); files = @() }
      New-Item -ItemType Directory -Force -Path (Split-Path $indexPath -Parent) | Out-Null
      @{ entries = $entryList } | ConvertTo-Json -Depth 6 | Set-Content -LiteralPath $indexPath -Encoding UTF8
      $prev = [pscustomobject]@{ uuid = $Uuid; folder = $dir; archivedAt = (Get-Date -Format o) }
    } catch { }
  }
  [pscustomobject]@{
    alreadyArchived = $true
    uuid            = $Uuid
    title           = $Title
    folder          = $(if ($prev) { $prev.folder } else { $dir })
    archivedAt      = $(if ($prev) { $prev.archivedAt } else { '' })
    hint            = '该听记已归档；如需重新归档并覆盖，请加 -Force'
  } | ConvertTo-Json -Depth 4
  exit 3
}
New-Item -ItemType Directory -Force -Path $dir | Out-Null

$written = New-Object System.Collections.Generic.List[string]
$errors = New-Object System.Collections.Generic.List[string]
$warnings = New-Object System.Collections.Generic.List[string]

# 01 Word 纪要
try {
  $payloadPath = Join-Path $env:TEMP ("pm-archive-" + [Guid]::NewGuid().ToString('N') + ".json")
  @{ title = $Title; uuid = $Uuid; detail = $detail } | ConvertTo-Json -Depth 12 | Set-Content -LiteralPath $payloadPath -Encoding UTF8
  $docxPath = Join-Path $dir "01-会议纪要-$safeTitle.docx"
  $py = Join-Path $env:USERPROFILE '.dsh\dsh-runtimes\dsh-primary-runtime\dependencies\python\python.exe'
  if (-not (Test-Path $py)) { $py = 'python' }
  $script = Join-Path $PSScriptRoot 'pm-minutes-docx.py'
  & $py $script --json $payloadPath --out $docxPath | Out-Null
  Remove-Item $payloadPath -ErrorAction SilentlyContinue
  if (Test-Path $docxPath) { $written.Add($docxPath) } else { $errors.Add('01 Word 生成失败') }
} catch { $errors.Add("01 Word: $($_.Exception.Message)") }

# 01-m：同内容的 Markdown 版（侧栏可直接阅读；Word 用于对外交付/打印）
try {
  $mdPath = Join-Path $dir "01-会议纪要-$safeTitle.md"
  $ml = New-Object System.Collections.Generic.List[string]
  $ml.Add("# $Title")
  $ml.Add('')
  $ml.Add('## 基本信息')
  $ml.Add('')
  if ($basic.startTime) { $ml.Add('- 开始时间: ' + ([DateTimeOffset]::FromUnixTimeMilliseconds([int64]$basic.startTime).LocalDateTime.ToString('yyyy-MM-dd HH:mm'))) }
  if ($basic.duration) { $ml.Add('- 时长: ' + [Math]::Round([double]$basic.duration / 1000) + ' 秒') }
  $ml.Add("- taskUuid: $Uuid")
  if ($basic.url) { $ml.Add('- 听记链接: ' + $basic.url) }
  $ml.Add('')
  $ml.Add('## AI 摘要')
  $ml.Add('')
  $sumText = $summaryNode.fullSummary
  if ($sumText) { foreach ($ln in ([string]$sumText -split "`n")) { $ml.Add($ln) } } else { $ml.Add('（无摘要）') }
  $ml.Add('')
  $ml.Add('## 行动项')
  $ml.Add('')
  $ml.Add('| 序号 | 行动项 | 负责人 | 截止时间 | 来源 |')
  $ml.Add('| --- | --- | --- | --- | --- |')
  $i2 = 0
  foreach ($a in @($todosNode.actions)) {
    $i2++
    $v = if ($a -is [string]) { $a } else { $a.value }
    if ($v -is [string] -and $v.TrimStart().StartsWith('{')) { try { $v = ($v | ConvertFrom-Json).value } catch { } }
    $ml.Add("| $i2 | $v | 未指定 | 未指定 | hasActions |")
  }
  foreach ($t in @($todosNode.dingtalkTodoList)) {
    $i2++
    $names = @(); foreach ($e in @($t.executorList)) { if ($e.name) { $names += $e.name } elseif ($e.nickName) { $names += $e.nickName } }
    $who = if ($names.Count) { ($names -join '、') } else { '未指定' }
    $due = if ($t.dueDate) { $t.dueDate } else { '未指定' }
    $ml.Add("| $i2 | $($t.title) | $who | $due | dingtalkTodo |")
  }
  if ($i2 -eq 0) { $ml.Add('| - | （未提取到行动项） | - | - | - |') }
  $ml.Add('')
  $ml.Add('## 关键词')
  $ml.Add('')
  $kw = @(); foreach ($k in @($keywordsNode.keywords)) { if ($k) { $kw += [string]$k } }
  $ml.Add($(if ($kw.Count) { ($kw -join ' · ') } else { '（无关键词）' }))
  $ml.Add('')
  $ml.Add('## 转写全文')
  $ml.Add('')
  $any = $false
  foreach ($p in @($transcriptNode.paragraphList)) {
    $who2 = if ($p.nickName) { $p.nickName } else { '发言人' }
    $txt = if ($p.paragraph) { $p.paragraph } else { $p.text }
    if ($txt) { $ml.Add("**$who2**：$txt"); $ml.Add(''); $any = $true }
  }
  if (-not $any) { $ml.Add('（无转写内容）') }
  Set-Content -LiteralPath $mdPath -Value $ml -Encoding UTF8
  $written.Add($mdPath)
} catch { $warnings.Add("01-m Markdown 版生成失败: $($_.Exception.Message)") }

# 02 录音
if (-not $NoAudio) {
  try {
    $audio = Unwrap (Invoke-Dws @('minutes', 'get', 'audio', '--id', $Uuid))
    $url = $audio.audioUrl
    if (-not $url) { $url = $audio.videoUrl }
    if ($url) {
      $ext = if ($url -match '\.mp4') { '.mp4' } elseif ($url -match '\.m4a') { '.m4a' } else { '.mp3' }
      $audioPath = Join-Path $dir ("02-录音-$safeTitle$ext")
      Invoke-WebRequest -Uri $url -OutFile $audioPath -TimeoutSec 600
      $written.Add($audioPath)
    } else { $warnings.Add('02 录音未归档：接口未返回地址（听记过期 / 无痕模式 / 媒体已删除）') }
  } catch { $warnings.Add("02 录音未归档: $($_.Exception.Message)") }
}

# 03 AI 摘要原文
try {
  $mdPath = Join-Path $dir "03-AI摘要-$safeTitle.md"
  $sum = $summaryNode.fullSummary
  if (-not $sum) { $sum = '（无摘要）' }
  Set-Content -LiteralPath $mdPath -Value $sum -Encoding UTF8
  $written.Add($mdPath)
} catch { $errors.Add("03 摘要: $($_.Exception.Message)") }

# 04 行动项 CSV
try {
  $csvPath = Join-Path $dir "04-行动项-$safeTitle.csv"
  $rows = New-Object System.Collections.Generic.List[object]
  $i = 0
  foreach ($a in @($todosNode.actions)) {
    $i++
    $val = if ($a -is [string]) { $a } else { $a.value }
    # actions 元素可能是 JSON 字符串（{"mark":[],"value":"..."}），解析出 value
    if ($val -is [string] -and $val.TrimStart().StartsWith('{')) {
      try { $val = ($val | ConvertFrom-Json).value } catch { }
    }
    $rows.Add([pscustomobject]@{ 序号 = $i; 行动项 = $val; 负责人 = ''; 截止时间 = ''; 来源 = 'hasActions' })
  }
  foreach ($t in @($todosNode.dingtalkTodoList)) {
    $i++
    $names = @()
    foreach ($e in @($t.executorList)) { if ($e.name) { $names += $e.name } elseif ($e.nickName) { $names += $e.nickName } }
    $rows.Add([pscustomobject]@{ 序号 = $i; 行动项 = $t.title; 负责人 = ($names -join '、'); 截止时间 = $t.dueDate; 来源 = 'dingtalkTodo' })
  }
  if ($rows.Count -eq 0) { $rows.Add([pscustomobject]@{ 序号 = 0; 行动项 = '（未提取到行动项）'; 负责人 = ''; 截止时间 = ''; 来源 = '' }) }
  $rows | Export-Csv -LiteralPath $csvPath -NoTypeInformation -Encoding UTF8
  $written.Add($csvPath)
} catch { $errors.Add("04 行动项: $($_.Exception.Message)") }

# 05 逐字稿
try {
  $trPath = Join-Path $dir "05-逐字稿-$safeTitle.md"
  $lines = New-Object System.Collections.Generic.List[string]
  foreach ($p in @($transcriptNode.paragraphList)) {
    $who = if ($p.nickName) { $p.nickName } else { '发言人' }
    $txt = if ($p.paragraph) { $p.paragraph } else { $p.text }
    if ($txt) { $lines.Add("**$who**：$txt") ; $lines.Add('') }
  }
  if ($lines.Count -eq 0) { $lines.Add('（无转写内容）') }
  Set-Content -LiteralPath $trPath -Value $lines -Encoding UTF8
  $written.Add($trPath)
} catch { $errors.Add("05 逐字稿: $($_.Exception.Message)") }

# 06 关键词
try {
  $kwPath = Join-Path $dir "06-关键词-$safeTitle.md"
  $kws = @()
  foreach ($k in @($keywordsNode.keywords)) { if ($k) { $kws += [string]$k } }
  Set-Content -LiteralPath $kwPath -Value (($kws -join ' · ') -replace '^$', '（无关键词）') -Encoding UTF8
  $written.Add($kwPath)
} catch { $errors.Add("06 关键词: $($_.Exception.Message)") }

# 归档索引：记录 uuid → 归档文件夹，供面板显示"已归档"状态
try {
  $entries = @()
  if (Test-Path $indexPath) { try { $entries = @((Get-Content $indexPath -Raw -Encoding UTF8 | ConvertFrom-Json).entries | Where-Object { -not ($_.uuid -eq $Uuid -and $_.project -eq $Project) }) } catch { } }
  $entries += [pscustomobject]@{ uuid = $Uuid; title = $Title; project = $Project; folder = $dir; archivedAt = (Get-Date -Format o); files = @($written) }
  New-Item -ItemType Directory -Force -Path (Split-Path $indexPath -Parent) | Out-Null
  @{ entries = $entries } | ConvertTo-Json -Depth 6 | Set-Content -LiteralPath $indexPath -Encoding UTF8
  # 同步一份到项目根的 .pm-cache（面板的缓存回退通道从这里读，保持可移植）
  try {
    $projCache = Join-Path (Join-Path $ProjectRoot $Project) '.pm-cache'
    New-Item -ItemType Directory -Force -Path $projCache | Out-Null
    @{ entries = $entries } | ConvertTo-Json -Depth 6 | Set-Content -LiteralPath (Join-Path $projCache 'archive-index.json') -Encoding UTF8
  } catch { }
} catch { $errors.Add("索引写入失败: $($_.Exception.Message)") }
[pscustomobject]@{
  ok          = ($errors.Count -eq 0)
  project     = $Project
  folder      = $dir
  files       = $written
  errors      = $errors
  warnings    = $warnings
  title       = $Title
} | ConvertTo-Json -Depth 5
