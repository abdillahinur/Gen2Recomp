#!/usr/bin/env sh
set -eu

if command -v luajit >/dev/null 2>&1; then
  exec luajit tests/run_tests.lua
fi

if command -v lua >/dev/null 2>&1; then
  exec lua tests/run_tests.lua
fi

echo "LuaJIT or Lua 5.1+ is required to run the headless tests." >&2
exit 1

