param(
  [string]$ProjectFile = "$PSScriptRoot/sample-project.json",
  [string]$AsOf = '2025-04-14',
  [int]$DelayScenarioDays = 0,
  [string]$OutputFile = "$PSScriptRoot/output/timeline-check.json"
)

$ErrorActionPreference = 'Stop'
$project = Get-Content -Raw -Encoding utf8 $ProjectFile | ConvertFrom-Json
$asOfDate = [datetime]::ParseExact($AsOf, 'yyyy-MM-dd', $null)

$atRisk = @($project.milestones | Where-Object { $_.status -eq 'At Risk' } | ForEach-Object {
  [pscustomobject]@{ id = $_.id; name = $_.name; planned_date = $_.planned_date; owner = $_.owner; source = $_.source }
})

$overdue = @($project.actions | Where-Object {
  $_.status -notin @('Done','Cancelled') -and $_.due_date -and ([datetime]::ParseExact($_.due_date, 'yyyy-MM-dd', $null) -lt $asOfDate)
} | ForEach-Object {
  [pscustomobject]@{ id = $_.id; action = $_.action; due_date = $_.due_date; owner = $_.owner; source = $_.source }
})

$criticalPath = @(
  [pscustomobject]@{ id = 'MS-001'; name = 'Technical package confirmation'; depends_on = @(); status = 'Done' },
  [pscustomobject]@{ id = 'MS-002'; name = 'Sample arrival'; depends_on = @('MS-001'); status = 'At Risk' },
  [pscustomobject]@{ id = 'MS-003'; name = 'Tech transfer gap assessment'; depends_on = @('MS-001','MS-002'); status = 'Planned' }
)

$scenario = @()
if ($DelayScenarioDays -gt 0) {
  $scenario = @([pscustomobject]@{
    scenario = "Client sample or prerequisite delayed $DelayScenarioDays days"
    impacted_milestone = 'MS-003'
    original_target = '2025-04-25'
    scenario_target = ([datetime]::ParseExact('2025-04-25','yyyy-MM-dd',$null).AddDays($DelayScenarioDays).ToString('yyyy-MM-dd'))
    assumption = 'Scenario only; Tech Transfer must confirm the actual processing window.'
  })
}

$result = [pscustomobject]@{
  project_id = $project.project_id
  as_of = $AsOf
  overall_status = $project.status
  at_risk_milestones = $atRisk
  overdue_actions = $overdue
  missing_fields = @('follow-up meeting date and link')
  critical_path = $criticalPath
  scenario_impacts = $scenario
  sources = @($ProjectFile, 'preset/tool-contracts.md')
}

$result | ConvertTo-Json -Depth 8 | Set-Content -Encoding utf8 $OutputFile
$result | ConvertTo-Json -Depth 8
