#!/usr/bin/env bash
set -eu
[ "${1:-}" = summary ] || { echo "usage: usage.sh summary APP [RUN_ID]" >&2; exit 2; }
shift
here=$(cd "$(dirname "$0")/../lib" && pwd)
exec python3 "$here/runner.py" usage "$@"
