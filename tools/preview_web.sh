#!/bin/sh
set -eu
cd "$(dirname "$0")/.."
exec python3 tools/run_first_playable.py web --build "$@"
