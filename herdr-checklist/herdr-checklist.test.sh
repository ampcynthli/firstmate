#!/usr/bin/env bash
# Self-check for herdr-checklist.sh: renderer selection, mtime change detection,
# and the starter skeleton. Run: ./herdr-checklist.test.sh
set -uo pipefail

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=herdr-checklist.sh disable=SC1091
source "$DIR/herdr-checklist.sh"

fail=0
check() {
  if [ "$2" = "$3" ]; then
    printf 'ok   %s\n' "$1"
  else
    printf 'FAIL %s: expected %q got %q\n' "$1" "$3" "$2"
    fail=1
  fi
}

# No candidate on PATH -> cat.
check renderer-fallback "$(pick_renderer definitely-not-real-xyz)" cat
# First existing candidate wins (sh and cat both exist; sh is listed first).
check renderer-first-found "$(pick_renderer sh cat)" sh
# Explicit override beats probing.
check renderer-override "$(HERDR_CHECKLIST_RENDERER=glow pick_renderer nope)" glow

# mtime read reflects a changed file.
tmp=$(mktemp)
m1=$(checklist_mtime "$tmp")
touch -t 203801010000 "$tmp"  # fixed far-future time; robust to sub-second clocks
m2=$(checklist_mtime "$tmp")
rm -f "$tmp"
if [ -n "$m1" ] && [ "$m1" != "$m2" ]; then
  check mtime-changes changed changed
else
  check mtime-changes "$m1->$m2" changed
fi

# Starter carries the owner and all four sections.
out=$(starter Cynthia)
for marker in "CHECKLIST — Cynthia" "🔴 ACT NOW" "🔵 IN FLIGHT" "🟡 WAITING" "🟢 RECENTLY DONE"; do
  case $out in
    *"$marker"*) printf 'ok   starter-has %s\n' "$marker" ;;
    *) printf 'FAIL starter-missing %s\n' "$marker"; fail=1 ;;
  esac
done

exit "$fail"
