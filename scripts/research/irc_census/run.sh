#!/usr/bin/env bash
# Full census: harvest every network, then rebuild the report.
#   ./run.sh                 collect + report
#   ./run.sh --refresh-frame rebuild networks.json from the public directory first
#   ./run.sh --report-only   rebuild the report from the last harvest
#   ./run.sh --only libera,rizon
set -euo pipefail
cd "$(dirname "$0")"

if [ "${1:-}" = "--report-only" ]; then
  exec python3 report.py
fi

if [ "${1:-}" = "--refresh-frame" ]; then
  shift
  python3 discover.py
fi

python3 collect.py "$@"
python3 report.py
