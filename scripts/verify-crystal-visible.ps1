param(
  [Parameter(Mandatory = $true)]
  [string]$RomPath
)

$ErrorActionPreference = "Stop"

$runtime = Get-Command lovec -ErrorAction SilentlyContinue
if (-not $runtime) {
  $runtime = Get-Command love -ErrorAction SilentlyContinue
}
if (-not $runtime) {
  throw "LOVE 11.x is required for visible Crystal fidelity verification."
}

$previousRom = $env:GEN2RECOMP_ROM_PATH
$previousFresh = $env:GEN2RECOMP_FRESH_PREVIEW
$previousFidelity = $env:GEN2RECOMP_FIDELITY_SMOKE_TEST
try {
  $env:GEN2RECOMP_ROM_PATH = (Resolve-Path -LiteralPath $RomPath).Path
  $env:GEN2RECOMP_FRESH_PREVIEW = "1"
  $env:GEN2RECOMP_FIDELITY_SMOKE_TEST = "1"
  & $runtime.Source "."
  if ($LASTEXITCODE -ne 0) {
    exit $LASTEXITCODE
  }
}
finally {
  $env:GEN2RECOMP_ROM_PATH = $previousRom
  $env:GEN2RECOMP_FRESH_PREVIEW = $previousFresh
  $env:GEN2RECOMP_FIDELITY_SMOKE_TEST = $previousFidelity
}
