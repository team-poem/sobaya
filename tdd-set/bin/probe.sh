#!/bin/bash
# RED=0, GREEN=1, ERROR=2. Diagnostics are printed; no package auto-install.
set -eu
root=$(cd "$(dirname "$0")/../.." && pwd -P)
exec /bin/bash "$root/scripts/probe.sh" "$@"
