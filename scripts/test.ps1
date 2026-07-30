$ErrorActionPreference = "Stop"

$runtime = Get-Command luajit -ErrorAction SilentlyContinue
if (-not $runtime) {
  $runtime = Get-Command lua -ErrorAction SilentlyContinue
}

if (-not $runtime) {
  throw "LuaJIT or Lua 5.1+ is required to run the headless tests."
}

& $runtime.Source "tests/run_tests.lua"
if ($LASTEXITCODE -ne 0) {
  exit $LASTEXITCODE
}

