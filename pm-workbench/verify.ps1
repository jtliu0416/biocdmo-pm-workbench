$ErrorActionPreference = 'Stop'
$bundle = Split-Path -Parent $MyInvocation.MyCommand.Path
$projectsPath = Join-Path $bundle 'projects.json'
$manifest = Get-Content -Raw -Encoding utf8 (Join-Path $bundle 'package.json') | ConvertFrom-Json
$projects = Get-Content -Raw -Encoding utf8 $projectsPath | ConvertFrom-Json
$patch = Get-Content -Raw -Encoding utf8 (Join-Path $bundle 'cordis.patch.yml')
$client = Get-Content -Raw -Encoding utf8 (Join-Path $bundle 'client.js')
$folderIndex = Get-Content -Raw -Encoding utf8 (Join-Path $bundle 'project-folder-index.json') | ConvertFrom-Json
$priorityIndex = Get-Content -Raw -Encoding utf8 (Join-Path $bundle 'priority-file-index.json') | ConvertFrom-Json

if ($manifest.name -ne '@local/dsh-biocdmo-pm-workbench') { throw 'Unexpected bundle name' }
if ($projects.projects.Count -ne 3) { throw 'Expected exactly three explicitly mapped projects' }
if (($projects.projects.project_id | Sort-Object) -join ',' -ne 'IP160,IP266,IP322') { throw 'Unexpected project allowlist' }
if ($patch -notmatch 'id: pm-workbench') { throw 'Missing pm-workbench loader row' }
if ($patch -notmatch '@local/dsh-biocdmo-pm-workbench') { throw 'Missing workbench module name' }
if ($client -notmatch "sidebar\.right\.tab\.document\.actions") { throw 'Missing native document preview file reference action' }
if ($client -notmatch "conversation\.input\.dock") { throw 'Missing removable Composer file reference chip' }
if ($client -notmatch 'function FileTreeRowActions') { throw 'Missing native tree row-action bridge' }
if ($client -notmatch 'sidebar\.right\.tab\.files\.actions') { throw 'Missing native files toolbar anchor' }
if ($client -notmatch 'data-files-entry="directory"' -or $client -notmatch 'data-files-entry="file"') { throw 'Row actions must cover folders and files' }
if ($client -notmatch 'pmfr-row-action') { throw 'Missing row-level reference button' }
if ($client -notmatch 'function SkillStrip') { throw 'Missing composer skill shortcut strip' }
if ($client -notmatch '加密此文件') { throw 'Missing encrypt skill button' }
if (-not (Test-Path (Join-Path $bundle 'encrypt-office.ps1'))) { throw 'Missing Office encryption script' }
if (-not (Test-Path (Join-Path $bundle 'merge-ppt.ps1'))) { throw 'Missing PPT merge script' }
$merge = Get-Content (Join-Path $bundle 'merge-ppt.ps1') -Raw
if ($merge -notmatch "00-SUM|排除|每部门") { throw 'merge-ppt.ps1 must document exclusion of 00-SUM and per-dept-latest rule' }
# Skills must exist in preset source and contain the mandatory constraints
foreach ($skill in @(
    @{ name = 'file-encryption'; must = @('\.pm-password', 'ProviderPath', 'SaveAs') },
    @{ name = 'ppt-merge'; must = @('merge-ppt\.ps1', '严禁现场编写', '00-SUM') }
  )) {
  $skillPath = Join-Path $bundle ('..\skills\' + $skill.name + '\SKILL.md')
  if (-not (Test-Path $skillPath)) { throw "Missing skill: $($skill.name)" }
  $skillBody = Get-Content $skillPath -Raw -Encoding UTF8
  foreach ($pattern in $skill.must) { if ($skillBody -notmatch $pattern) { throw "Skill $($skill.name) missing required content: $pattern" } }
}
if ($client -match 'pmfr-reference-now') { throw 'Obsolete two-step Composer reference button must not remain' }
if ($client -notmatch 'referenceText\(file\)') { throw 'Missing exact file reference prompt function' }
if ($client -notmatch 'workspaceFiles\.stat') { throw 'Missing read-only file version lookup' }
if ($client -notmatch 'function allowed') { throw 'Missing explicit project-root path guard' }
if ($client -match "workspaces\.create|uiWorkspace\.openWorkspace") { throw 'Project Workspace navigation UI must not be reintroduced' }
# sidebarRight.openTabIn 现为会议纪要原生 tab 的合法用法（与 BrowserSkill 同契约）；仅禁止用于打开 Workspace 导航
if ($client -match "sidebarRight\.openTabIn\([^)]*(?:workspace|files-root)") { throw 'openTabIn must not be used to open Workspace navigation' }
if ($client -match "shell\.overlay") { throw 'Floating project file drawer must not remain' }
if ($client -match "sidebar\.panellist") { throw 'Standalone PM Workbench sidebar entry must not remain' }
# 旧守卫收窄：仅禁止"PM 自绘文件树"占用 pane.tab（key 为 pm-file-tree）；会议纪要 tab（key=minutes）为合法用法
if ($client -match "pane\.tab[\s\S]{0,120}pm-file-tree|pm-file-tree[\s\S]{0,120}pane\.tab") { throw 'Custom PM file tree must not replace native Workspace Files' }
# 会议纪要：经 better-sidebar 服务注册（ctx.betterSidebar.registerTab）+ 宿主 /pm-minutes 路由
if (($client -notmatch 'betterSidebar') -or ($client -notmatch 'registerTab') -or ($client -notmatch 'pm-workbench:minutes') -or ($client -notmatch '/sidebar/file')) { throw 'Missing better-sidebar minutes tab registration' }
if ($null -eq $priorityIndex.projects) { throw 'Missing captured priority file evidence' }
if ($client -match 'disabled: true') { throw 'Custom summary UI must not remain in native file mode' }
if ($manifest.dsh.client.inject -notcontains '@deepseek-ai/dsh-client-ui-sidebar-files') { throw 'Missing native files client dependency' }

$expectedParent = Split-Path -Parent ([string]$projects.projects[0].file_root)
if (-not (Test-Path -LiteralPath $expectedParent)) { throw 'Configured project parent is unavailable' }
foreach ($project in $projects.projects) {
  if ($project.access_mode -ne 'workspace-mounted') { throw "Project $($project.project_id) is not a normal mounted Workspace" }
  $fileRoot = [string]($project.file_root)
  if ((Split-Path -Parent $fileRoot) -ne $expectedParent) { throw "Project $($project.project_id) is outside the configured project parent" }
  if ((Split-Path -Leaf $fileRoot) -ne $project.project_id) { throw "Project $($project.project_id) root leaf does not match explicit project ID" }
  if (-not (Test-Path -LiteralPath $fileRoot)) { throw "Project root unavailable: $fileRoot" }
  $liveFolders = @(Get-ChildItem -LiteralPath $fileRoot -Directory -Force | ForEach-Object { $_.Name })
  $priorityProject = $priorityIndex.projects.($project.project_id)
  if ($null -eq $priorityProject) { throw "Missing priority file index for $($project.project_id)" }
  foreach ($categoryId in @('progress', 'minutes')) {
    $category = $priorityProject.categories.($categoryId)
    if ($null -eq $category) { throw "Missing $categoryId category for $($project.project_id)" }
    $categoryPath = Join-Path $fileRoot ([string]$category.folder)
    if (-not (Test-Path -LiteralPath $categoryPath)) { throw "Priority category root unavailable: $categoryPath" }
    if ($category.files.Count -gt 25) { throw "Priority category exceeds bounded display cap: $($project.project_id) / $categoryId" }
    foreach ($file in $category.files) {
      $candidate = Join-Path $categoryPath ([string]$file.relative_path)
      if (-not (Test-Path -LiteralPath $candidate -PathType Leaf)) { throw "Indexed file unavailable: $candidate" }
      if ((Split-Path -Parent $candidate).StartsWith($expectedParent) -ne $true) { throw "Indexed file escapes mapped project root: $candidate" }
    }
  }
  $indexedProject = $folderIndex.projects.($project.project_id)
  if ($null -eq $indexedProject) { throw "Missing captured folder index for $($project.project_id)" }
  foreach ($folder in $indexedProject.root_listing) {
    if ($liveFolders -notcontains $folder) { throw "Indexed folder $folder is no longer present in $($project.project_id)" }
  }
  Write-Output "OK $($project.project_id) -> $fileRoot ($($indexedProject.root_listing.Count) indexed folders)"
}
$hostSource = Get-Content -Raw -Encoding utf8 (Join-Path $bundle 'index.js')

if (-not (Test-Path (Join-Path $PSScriptRoot 'archive-minutes.ps1'))) { throw 'missing archive-minutes.ps1' }

# ---- 架构守卫：宿主路由方案已被彻底废弃，禁止复活（历史上反复导致 404 / 需重启） ----
$hostSource = Get-Content -Raw -Encoding utf8 (Join-Path $bundle 'index.js')
$hostCode = (($hostSource -split "`n") | Where-Object { $_ -notmatch '^\s*(//|\*|/\*)' }) -join "`n"   # 忽略注释行
if ($hostCode -match 'webServer\.register|ROUTE_BASE') { throw 'Host routes must not come back: panel reads .pm-cache only (see index.js header)' }
if ($client -match 'MINUTES_API|/pm-minutes') { throw 'Client must not call host routes: it reads .pm-cache via /sidebar/file' }
if ($client -notmatch '\.pm-workbench/cache') { throw 'Client must read the user-central cache (~/.pm-workbench/cache)' }
if ($hostSource -match 'export const (name|inject)') { throw 'Exporting name/inject stops cordis from calling apply (see index.js header)' }
# 开发教训文档必须存在（防止经验丢失、防止重走宿主路由老路）
$lessons = Join-Path (Split-Path $bundle -Parent) 'docs\pm-workbench-dev-lessons.md'
if (-not (Test-Path $lessons)) { throw 'Missing dev-lessons doc: docs/pm-workbench-dev-lessons.md' }
if (-not (Select-String -Path $lessons -SimpleMatch '禁止再引入任何宿主路由' -Quiet)) { throw 'dev-lessons doc must state the host-route prohibition' }
# 分发/配置文档必须存在（依赖链与安装顺序的单一来源）
$deploy = Join-Path (Split-Path $bundle -Parent) 'docs\pm-workbench-deployment.md'
if (-not (Test-Path $deploy)) { throw 'Missing deployment doc: docs/pm-workbench-deployment.md' }
# ---- profile 健康守卫：package.json 无 BOM、可解析、我们的包在册、废弃插件无残留 ----
$profilePkg = Join-Path $env:USERPROFILE '.dsh\profiles\desktop\package.json'
if (Test-Path $profilePkg) {
  $bytes = [IO.File]::ReadAllBytes($profilePkg)[0..2]
  if ($bytes[0] -eq 0xEF -and $bytes[1] -eq 0xBB -and $bytes[2] -eq 0xBF) { throw 'Profile package.json has UTF-8 BOM: DSH host will crash on boot (rewrite without BOM)' }
  try { $pj = Get-Content $profilePkg -Raw -Encoding UTF8 | ConvertFrom-Json } catch { throw "Profile package.json is not valid JSON: $($_.Exception.Message)" }
  if ($pj.dsh.profile.bundles -notcontains '@local/dsh-biocdmo-pm-workbench') { throw 'Profile bundles lost @local/dsh-biocdmo-pm-workbench' }
  if ($pj.dependencies.'dsh-email') { throw 'dsh-email is banned: its installer writes BOM into profile package.json (boot crash)' }
}
Write-Output 'PM WORKBENCH MVP VALIDATION PASSED'
