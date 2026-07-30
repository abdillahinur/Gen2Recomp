param(
  [Parameter(Mandatory = $true)]
  [string]$RomPath
)

$ErrorActionPreference = "Stop"

$runtime = Get-Command love -ErrorAction SilentlyContinue
if (-not $runtime) {
  throw "LÖVE 11.x is required to run the battle preview."
}

$previousRom = $env:GEN2RECOMP_ROM_PATH
$previousBattle = $env:GEN2RECOMP_BATTLE_PREVIEW
try {
  $env:GEN2RECOMP_ROM_PATH = (Resolve-Path -LiteralPath $RomPath).Path
  $env:GEN2RECOMP_BATTLE_PREVIEW = "1"
  & $runtime.Source "."
  if ($LASTEXITCODE -ne 0) {
    exit $LASTEXITCODE
  }
}
finally {
  $env:GEN2RECOMP_ROM_PATH = $previousRom
  $env:GEN2RECOMP_BATTLE_PREVIEW = $previousBattle
}
