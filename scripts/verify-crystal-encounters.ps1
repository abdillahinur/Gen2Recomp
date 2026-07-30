param(
  [Parameter(Mandatory = $true)]
  [string]$RomPath
)

$ErrorActionPreference = "Stop"

$runtime = Get-Command luajit -ErrorAction SilentlyContinue
if (-not $runtime) {
  $runtime = Get-Command lua -ErrorAction SilentlyContinue
}
if (-not $runtime) {
  throw "LuaJIT or Lua 5.1+ is required for M5-006 verification."
}

$resolved = (Resolve-Path -LiteralPath $RomPath).Path
& $runtime.Source "tools/verify_crystal_encounters.lua" $resolved
if ($LASTEXITCODE -ne 0) {
  exit $LASTEXITCODE
}
