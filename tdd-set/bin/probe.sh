#!/usr/bin/env bash
# RED=0, GREEN=1, ERROR=2. Full diagnostics are printed. No runtime/package download.
set -eu
here=$(cd "$(dirname "$0")/../.." && pwd)
exec python3 "$here/scripts/probe.py" "$@"
