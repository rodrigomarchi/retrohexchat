#!/usr/bin/env bash
# Quick summary of remaining Windows 98 / 98.css references.
# Wrapper around find-win98-refs.sh --count
set -euo pipefail
exec "$(dirname "$0")/find-win98-refs.sh" --count
