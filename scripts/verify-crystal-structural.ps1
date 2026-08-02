param(
  [Parameter(Mandatory = $true)]
  [string]$RomPath
)

$ErrorActionPreference = "Stop"
$resolved = (Resolve-Path -LiteralPath $RomPath).Path

$gates = @(
  "verify-crystal-intro.ps1",
  "verify-crystal-text.ps1",
  "verify-crystal-events.ps1",
  "verify-crystal-violet-events.ps1",
  "verify-crystal-vertical-slice.ps1",
  "verify-crystal-save.ps1",
  "verify-crystal-audio.ps1",
  "verify-crystal-audio-live.ps1",
  "verify-crystal-visible.ps1"
)

foreach ($gate in $gates) {
  & (Join-Path $PSScriptRoot $gate) -RomPath $resolved
  if ($LASTEXITCODE -ne 0) {
    exit $LASTEXITCODE
  }
}

Write-Host "Crystal structural and visible smoke checks passed (9/9 gates)."
