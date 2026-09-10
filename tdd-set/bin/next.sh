#!/usr/bin/env bash
set -eu
here=$(cd "$(dirname "$0")/../lib" && pwd)
exec python3 "$here/runner.py" next "$@"
