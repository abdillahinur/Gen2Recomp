param(
  [string]$RomPath
)

$ErrorActionPreference = "Stop"

$runtime = Get-Command lovec -ErrorAction SilentlyContinue
if (-not $runtime) {
  $runtime = Get-Command love -ErrorAction SilentlyContinue
}

if (-not $runtime) {
  throw "LÖVE 11.x is required to run the smoke test."
}

$previous = $env:GEN2RECOMP_SMOKE_TEST
$previousRom = $env:GEN2RECOMP_ROM_PATH
try {
  $env:GEN2RECOMP_SMOKE_TEST = "1"
  if ($RomPath) {
    $env:GEN2RECOMP_ROM_PATH = (Resolve-Path -LiteralPath $RomPath).Path
  }
  & $runtime.Source "."
  if ($LASTEXITCODE -ne 0) {
    exit $LASTEXITCODE
  }
}
finally {
  $env:GEN2RECOMP_SMOKE_TEST = $previous
  $env:GEN2RECOMP_ROM_PATH = $previousRom
}
