#!/bin/sh
# Run the test suite headlessly. Pass a spec file or directory to narrow it down.
cd "$(dirname "$0")/.." || exit 1
target="${1:-tests/}"
if [ -f "$target" ]; then
  cmd="lua require('plenary.busted').run('$target')"
else
  cmd="PlenaryBustedDirectory $target {minimal_init = 'tests/minimal_init.lua', sequential = true}"
fi
exec nvim --headless --noplugin -u tests/minimal_init.lua -c "$cmd"
