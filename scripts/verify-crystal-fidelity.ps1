param(
  [Parameter(Mandatory = $true)]
  [string]$RomPath
)

$ErrorActionPreference = "Stop"
Write-Warning (
  "verify-crystal-fidelity.ps1 is a legacy alias. " +
  "These checks prove structure and reachability, not cartridge parity."
)
& (Join-Path $PSScriptRoot "verify-crystal-structural.ps1") `
  -RomPath $RomPath
