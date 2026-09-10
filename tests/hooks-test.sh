#!/bin/sh
# Provider-neutral integration regressions: real Git hooks, setup, index and probes.
set -eu
root=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
exec python3 "$root/tests/test_tools.py"
