#!/usr/bin/env sh
set -eu

if command -v luajit >/dev/null 2>&1; then
  runtime=luajit
elif command -v lua >/dev/null 2>&1; then
  runtime=lua
else
  echo "LuaJIT or Lua 5.1+ is required to run the headless tests." >&2
  exit 1
fi

"$runtime" tests/run_tests.lua
python3 -m unittest discover -s tools/tests
