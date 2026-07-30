param(
  [Parameter(Mandatory = $true)]
  [string]$RomPath
)

$ErrorActionPreference = "Stop"

$resolvedRom = (Resolve-Path -LiteralPath $RomPath).Path
$runtime = Get-Command love -ErrorAction SilentlyContinue
if (-not $runtime) {
  throw "LÖVE 11.x is required to run the M2 preview."
}

$previous = $env:GEN2RECOMP_ROM_PATH
try {
  $env:GEN2RECOMP_ROM_PATH = $resolvedRom
  & $runtime.Source "."
  if ($LASTEXITCODE -ne 0) {
    exit $LASTEXITCODE
  }
}
finally {
  $env:GEN2RECOMP_ROM_PATH = $previous
}
