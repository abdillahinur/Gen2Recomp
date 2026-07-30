param(
  [Parameter(Mandatory = $true)]
  [string]$RomPath,
  [switch]$Fresh
)

$ErrorActionPreference = "Stop"

$runtime = Get-Command love -ErrorAction SilentlyContinue
if (-not $runtime) {
  throw "LÖVE 11.x is required to run the Crystal preview."
}

$previousRom = $env:GEN2RECOMP_ROM_PATH
$previousFresh = $env:GEN2RECOMP_FRESH_PREVIEW
try {
  $env:GEN2RECOMP_ROM_PATH = (Resolve-Path -LiteralPath $RomPath).Path
  $env:GEN2RECOMP_FRESH_PREVIEW = if ($Fresh) { "1" } else { $null }
  & $runtime.Source "."
  if ($LASTEXITCODE -ne 0) {
    exit $LASTEXITCODE
  }
}
finally {
  $env:GEN2RECOMP_ROM_PATH = $previousRom
  $env:GEN2RECOMP_FRESH_PREVIEW = $previousFresh
}
