$ErrorActionPreference = 'Stop'

$presetFile = Join-Path $PSScriptRoot 'biocdmo-pm-harness.patch.yml'
$profileFile = Join-Path $env:DSH_PROFILE_DIR 'cordis.patch.yml'
$required = @(
  'id: preset-biocdmo-pm-harness',
  'name: ''@deepseek-ai/dsh-agent-preset''',
  'id: biocdmo-pm-harness',
  'name: BioCDMO PM Harness',
  'name: ''@deepseek-ai/dsh-persona''',
  'You are BioCDMO PM Harness'
)

foreach ($file in @($presetFile, $profileFile)) {
  $content = Get-Content -Raw -Encoding utf8 $file
  foreach ($text in $required) {
    if (-not $content.Contains($text)) { throw "Missing '$text' in $file" }
  }
  Write-Output "STATIC PRESET CHECK PASSED: $file"
}

Write-Output 'Runtime registration requires restarting DeepSeek Harness, then selecting BioCDMO PM Harness in a new blank session.'
