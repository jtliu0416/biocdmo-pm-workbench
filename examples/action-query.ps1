param(
  [string]$ProjectFile = "$PSScriptRoot/sample-project.json",
  [string]$AsOf = '2025-04-14',
  [ValidateSet('all','overdue','due_soon','client_owned','unassigned')]
  [string]$Filter = 'all',
  [int]$DaysAhead = 7,
  [string]$OutputFile = "$PSScriptRoot/output/action-query.json"
)

$ErrorActionPreference = 'Stop'
$project = Get-Content -Raw -Encoding utf8 $ProjectFile | ConvertFrom-Json
$asOfDate = [datetime]::ParseExact($AsOf, 'yyyy-MM-dd', $null)
$endDate = $asOfDate.AddDays($DaysAhead)

$classified = @($project.actions | ForEach-Object {
  $due = $null
  if ($_.due_date) { $due = [datetime]::ParseExact($_.due_date, 'yyyy-MM-dd', $null) }
  $isOpen = $_.status -notin @('Done','Cancelled')
  $isOverdue = $isOpen -and $due -and ($due -lt $asOfDate)
  $isDueSoon = $isOpen -and $due -and ($due -ge $asOfDate) -and ($due -le $endDate)
  $isClient = $_.owner_type -eq 'Client'
  $isUnassigned = [string]::IsNullOrWhiteSpace([string]$_.owner) -or $_.owner_type -eq 'Unknown'
  [pscustomobject]@{
    id = $_.id; action = $_.action; owner = $_.owner; owner_type = $_.owner_type
    due_date = $_.due_date; status = $_.status; source = $_.source
    overdue = [bool]$isOverdue; due_soon = [bool]$isDueSoon; client_owned = [bool]$isClient; unassigned = [bool]$isUnassigned
  }
})

$actions = @($classified | Where-Object {
  $item = $_
  if ($Filter -eq 'overdue') { return $item.overdue }
  if ($Filter -eq 'due_soon') { return $item.due_soon }
  if ($Filter -eq 'client_owned') { return $item.client_owned }
  if ($Filter -eq 'unassigned') { return $item.unassigned }
  return $true
})

$result = [pscustomobject]@{
  project_id = $project.project_id
  as_of = $AsOf
  filter = $Filter
  actions = $actions
  counts = [pscustomobject]@{
    total = @($classified).Count
    overdue = @($classified | Where-Object overdue).Count
    due_soon = @($classified | Where-Object due_soon).Count
    client_owned = @($classified | Where-Object client_owned).Count
    unassigned = @($classified | Where-Object unassigned).Count
  }
  sources = @($ProjectFile, 'preset/tool-contracts.md')
}

$result | ConvertTo-Json -Depth 8 | Set-Content -Encoding utf8 $OutputFile
$result | ConvertTo-Json -Depth 8
