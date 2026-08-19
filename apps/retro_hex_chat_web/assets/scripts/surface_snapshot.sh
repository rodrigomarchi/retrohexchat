#!/bin/sh
#
# Snapshot of everything the browser side exposes to the outside world.
#
# A standardisation refactor moves code without changing behaviour, and this is
# what makes that claim checkable rather than aspirational: if a hook is split
# into a lib module and an event name, a payload key or a data-* attribute
# changes on the way, the snapshot diff says so before the commit lands.
#
#   sh scripts/surface_snapshot.sh           regenerate js/SURFACE.txt
#   sh scripts/surface_snapshot.sh --check   fail when the tree drifted from it
#
# Four sections, each sorted and de-duplicated:
#
#   liveview-events  every string handed to pushEvent/pushEventTo/handleEvent
#   channel-events   every Phoenix Channel topic pushed or subscribed to
#   custom-events    DOM event names hooks listen for or dispatch
#   dataset-keys     every data-* key read or written, i.e. the contract with HEEx
#
# The extraction is deliberately textual. A parser would resolve names that are
# built at runtime, and those are exactly the ones a refactor cannot verify
# anyway; a literal that moves between files still reads as unchanged here,
# which is the property we want.
set -eu

cd "$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)"

SNAPSHOT="js/SURFACE.txt"

generate() {
  echo "## liveview-events"
  # pushEvent/pushEventTo/handleEvent in hooks, plus the reducer helpers that a
  # slice extracts them into: a bare push("event") not preceded by a dot (so
  # channel.push topics, tracked separately below, are not swept in here).
  {
    grep -rhoE '(pushEvent|pushEventTo|handleEvent)\([^)]*' js/ \
      | grep -oE '"[a-zA-Z_0-9:.-]+"'
    grep -rhoE '(^|[^.a-zA-Z_])push\("[a-zA-Z_0-9:.-]+"' js/lib/ \
      | grep -oE '"[a-zA-Z_0-9:.-]+"'
  } | tr -d '"' | LC_ALL=C sort -u
  echo "## channel-events"
  grep -rhoE '\.(push|on)\("[a-zA-Z_0-9:.-]+"' js/ \
    | grep -oE '"[a-zA-Z_0-9:.-]+"' | tr -d '"' | LC_ALL=C sort -u
  echo "## custom-events"
  # Scans all of js/ — like the other sections — because a controller extracted
  # from a hook keeps its listeners and dispatches, so the event name lives in
  # js/lib/ now; a hooks-only scan would silently drop it on the move.
  grep -rhoE '(CustomEvent|addEventListener|dispatchEvent)\([^,)]*' js/ \
    | grep -oE '"[a-zA-Z_0-9:.-]+"' | tr -d '"' | LC_ALL=C sort -u
  echo "## dataset-keys"
  grep -rhoE 'dataset\.[a-zA-Z0-9]+' js/ | LC_ALL=C sort -u
}

if [ "${1:-}" = "--check" ]; then
  if [ ! -f "$SNAPSHOT" ]; then
    echo "surface_snapshot: $SNAPSHOT is missing; run the script with no arguments." >&2
    exit 1
  fi

  if generate | diff -u "$SNAPSHOT" - > /tmp/surface_snapshot_diff.$$; then
    rm -f /tmp/surface_snapshot_diff.$$
    echo "Observable surface unchanged."
    exit 0
  fi

  echo "Observable surface changed. A standardisation refactor must not do this." >&2
  echo "Either restore the names, or move the change to its own behavioural commit" >&2
  echo "and regenerate with: sh scripts/surface_snapshot.sh" >&2
  echo >&2
  sed 's/^/  /' /tmp/surface_snapshot_diff.$$ >&2
  rm -f /tmp/surface_snapshot_diff.$$
  exit 1
fi

generate > "$SNAPSHOT"
echo "Wrote $SNAPSHOT ($(grep -vc '^##' "$SNAPSHOT") entries)."
