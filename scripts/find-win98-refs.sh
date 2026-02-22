#!/usr/bin/env bash
# Find all textual references to "Windows 98", "98.css", and related terms.
# Exit 0 = clean (no matches), Exit 1 = matches found.
# Usage: ./scripts/find-win98-refs.sh [--count]

set -euo pipefail

cd "$(dirname "$0")/.."

PATTERN='Windows 98\|Win98\|win98\|98\.css\|98css'

# Directories and files to exclude
EXCLUDE_DIRS='--exclude-dir=node_modules --exclude-dir=_build --exclude-dir=deps --exclude-dir=.git --exclude-dir=cover --exclude-dir=vendor --exclude-dir=.elixir_ls --exclude-dir=.lexical'
EXCLUDE_FILES='--exclude=*.beam --exclude=*.ez --exclude=*.png --exclude=*.jpg --exclude=*.gif --exclude=*.ico --exclude=*.woff --exclude=*.woff2 --exclude=*.ttf'

# File-level exclusions (grep -v on file paths)
exclude_by_file='scripts/find-win98-refs.sh\|scripts/win98-refs-summary.sh\|priv/static/\|\.svg:'

# Line-level exclusions (legitimate file paths / imports that must stay)
exclude_by_line='@import.*vendor/98\.css\|assets/vendor/98\.css/98\.css\|jdan\.github\.io/98\.css'

# Always get line-level matches first, then filter
# shellcheck disable=SC2086
raw=$(grep -rnI $EXCLUDE_DIRS $EXCLUDE_FILES "$PATTERN" . 2>/dev/null || true)

# Apply all exclusions
matches=""
if [[ -n "$raw" ]]; then
  matches=$(echo "$raw" | grep -v "$exclude_by_file" | grep -v "$exclude_by_line" || true)
fi

if [[ -z "$matches" ]]; then
  echo "No Windows 98 / 98.css references found. Clean!"
  exit 0
fi

if [[ "${1:-}" == "--count" ]]; then
  echo "=== Windows 98 / 98.css references per file ==="
  echo ""
  # Count matches per file
  total=0
  echo "$matches" | sed 's|^\./||' | cut -d: -f1 | sort | uniq -c | sort -rn | while read -r count file; do
    printf "  %4d  %s\n" "$count" "$file"
  done
  total=$(echo "$matches" | wc -l | tr -d ' ')
  files=$(echo "$matches" | sed 's|^\./||' | cut -d: -f1 | sort -u | wc -l | tr -d ' ')
  echo ""
  echo "Total: $total references in $files files"
  exit 1
else
  echo "=== Windows 98 / 98.css references ==="
  echo ""
  echo "$matches" | sed 's|^\./||'
  echo ""
  total=$(echo "$matches" | wc -l | tr -d ' ')
  echo "Total: $total matches"
  exit 1
fi
