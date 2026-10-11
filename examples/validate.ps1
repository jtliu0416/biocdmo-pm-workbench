param(
  [string]$ProjectFile = "$PSScriptRoot/sample-project.json",
  [string]$MeetingFile = "$PSScriptRoot/sample-meeting.txt",
  [string]$OutputDir = "$PSScriptRoot/output"
)

$ErrorActionPreference = 'Stop'

# This validator checks the deterministic contract of the sample fixture.
# It does not call external services and does not send or modify business data.
$project = Get-Content -Raw -Encoding utf8 $ProjectFile | ConvertFrom-Json
$meeting = Get-Content -Raw -Encoding utf8 $MeetingFile

$checks = [System.Collections.Generic.List[object]]::new()
function Check([string]$Name, [bool]$Passed, [string]$Detail) {
  $checks.Add([pscustomobject]@{ Name = $Name; Passed = $Passed; Detail = $Detail })
}

Check 'Project JSON parses' ($null -ne $project.project_id) $project.project_id
Check 'Project status is Amber' ($project.status -eq 'Amber') $project.status
Check 'Meeting has sample date' ($meeting.Contains('2025-04-09')) '2025-04-09'
Check 'Client confirmation due date exists' ($meeting.Contains('15')) 'day 15'
Check 'Gap assessment date exists' ($meeting.Contains('25')) 'day 25'
Check 'Internal minutes generated' (Test-Path (Join-Path $OutputDir 'internal-meeting-minutes.md')) 'internal-meeting-minutes.md'
Check 'Client minutes generated' (Test-Path (Join-Path $OutputDir 'client-meeting-minutes.md')) 'client-meeting-minutes.md'
Check 'Weekly review generated' (Test-Path (Join-Path $OutputDir 'weekly-review.md')) 'weekly-review.md'
Check 'Email draft generated' (Test-Path (Join-Path $OutputDir 'client-follow-up-email.md')) 'client-follow-up-email.md'
& "$PSScriptRoot/timeline-check.ps1" -OutputFile (Join-Path $OutputDir 'timeline-check.json') | Out-Null
$timeline = Get-Content -Raw -Encoding utf8 (Join-Path $OutputDir 'timeline-check.json') | ConvertFrom-Json
Check 'Timeline check generated' ($timeline.project_id -eq $project.project_id) $timeline.project_id
Check 'At-risk milestone detected' (@($timeline.at_risk_milestones).Count -eq 1) $timeline.at_risk_milestones[0].id
& "$PSScriptRoot/action-query.ps1" -OutputFile (Join-Path $OutputDir 'action-query.json') | Out-Null
$actions = Get-Content -Raw -Encoding utf8 (Join-Path $OutputDir 'action-query.json') | ConvertFrom-Json
Check 'Action query generated' ($actions.project_id -eq $project.project_id) $actions.project_id
Check 'Client action detected' ($actions.counts.client_owned -eq 1) $actions.counts.client_owned
& "$PSScriptRoot/project-search.ps1" -Query 'tech' -OutputFile (Join-Path $OutputDir 'project-search.json') | Out-Null
$search = Get-Content -Raw -Encoding utf8 (Join-Path $OutputDir 'project-search.json') | ConvertFrom-Json
Check 'Project search generated' ($search.project_id -eq $project.project_id) $search.project_id
Check 'Project search found sample' (@($search.matches).Count -ge 1) @($search.matches).Count

$failed = @($checks | Where-Object { -not $_.Passed })
$checks | Format-Table -AutoSize
if ($failed.Count -gt 0) {
  throw "Validation failed: $($failed.Count) check(s)"
}
Write-Output "VALIDATION PASSED: $($checks.Count) checks"
