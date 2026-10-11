param(
  [string]$ProjectFile = "$PSScriptRoot/sample-project.json",
  [Parameter(Mandatory=$true)][string]$Query,
  [ValidateSet('all','project','milestone','action','risk','document','contract_obligation')]
  [string]$Entity = 'all',
  [string]$OutputFile = "$PSScriptRoot/output/project-search.json"
)

$ErrorActionPreference = 'Stop'
$project = Get-Content -Raw -Encoding utf8 $ProjectFile | ConvertFrom-Json
$needle = $Query.Trim().ToLowerInvariant()

function Match-Text([object]$Value) {
  return ([string]$Value).ToLowerInvariant().Contains($needle)
}
function Add-Match([System.Collections.Generic.List[object]]$List, [string]$EntityName, [string]$Id, [string]$Field, [string]$Content, [string]$Source) {
  if (Match-Text $Content) {
    $List.Add([pscustomobject]@{ entity = $EntityName; id = $Id; field = $Field; content = $Content; source = $Source })
  }
}

$matches = [System.Collections.Generic.List[object]]::new()
if ($Entity -in @('all','project')) {
  Add-Match $matches 'project' $project.project_id 'project_name' $project.project_name 'project record'
  Add-Match $matches 'project' $project.project_id 'client' $project.client 'project record'
  Add-Match $matches 'project' $project.project_id 'stage' $project.stage 'project record'
  Add-Match $matches 'project' $project.project_id 'status' $project.status 'project record'
}
if ($Entity -in @('all','milestone')) {
  foreach ($item in @($project.milestones)) { Add-Match $matches 'milestone' $item.id 'name' $item.name $item.source }
}
if ($Entity -in @('all','action')) {
  foreach ($item in @($project.actions)) { Add-Match $matches 'action' $item.id 'action' $item.action $item.source }
}
if ($Entity -in @('all','risk')) {
  foreach ($item in @($project.risks)) { Add-Match $matches 'risk' $item.id 'description' $item.description $item.source }
}
if ($Entity -in @('all','document')) {
  foreach ($item in @($project.documents)) { Add-Match $matches 'document' $item.id 'name' $item.name $item.source }
}
if ($Entity -in @('all','contract_obligation')) {
  foreach ($item in @($project.contract_obligations)) { Add-Match $matches 'contract_obligation' $item.id 'obligation' $item.obligation $item.contract_source }
}

$result = [pscustomobject]@{ project_id = $project.project_id; query = $Query; entity = $Entity; matches = @($matches); sources = @($ProjectFile, 'preset/tool-contracts.md') }
$result | ConvertTo-Json -Depth 8 | Set-Content -Encoding utf8 $OutputFile
$result | ConvertTo-Json -Depth 8
