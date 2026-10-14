#!/bin/bash
set -eu
here=$(cd "$(dirname "$0")/../lib" && pwd)
exec /bin/bash "$here/runner.sh" migrate "$@"
