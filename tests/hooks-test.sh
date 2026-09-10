#!/bin/sh
# Neutral shell tools regression suite; no interpreter beyond the app runtimes.
set -eu
root=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
exec /bin/bash "$root/tests/test-tools.sh"
