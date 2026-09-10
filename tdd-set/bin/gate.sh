#!/usr/bin/env bash
# Acceptance is tied to the approved baseline and the exact clean HEAD.
set -eu
here=$(cd "$(dirname "$0")" && pwd)
exec python3 "$here/../lib/contract.py" "$@"
