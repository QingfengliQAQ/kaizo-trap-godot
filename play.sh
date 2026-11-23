#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")"
exec ./tools/godot/godot4 --path game "$@"
