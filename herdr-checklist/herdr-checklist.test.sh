#!/usr/bin/env bash
# Self-check for herdr-checklist.sh: fingerprint change detection, file-path
# resolution, renderer selection, and the starter skeleton.
# Run: ./herdr-checklist.test.sh
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

# Renderer: fall back to cat, honor first-found ordering, honor override.
check renderer-fallback "$(pick_renderer definitely-not-real-xyz)" cat
check renderer-first-found "$(pick_renderer sh cat)" sh
check renderer-override "$(HERDR_CHECKLIST_RENDERER=glow pick_renderer nope)" glow

# Fingerprint is content-based: a same-length edit (which whole-second mtime
# would miss) must change it, and a missing file reads "missing".
tmp=$(mktemp)
printf 'AAAA' >"$tmp"; fp1=$(fingerprint "$tmp")
printf 'BBBB' >"$tmp"; fp2=$(fingerprint "$tmp")  # same length, different bytes
if [ "$fp1" != "$fp2" ]; then check fingerprint-content-change changed changed
else check fingerprint-content-change "$fp1==$fp2" changed; fi
rm -f "$tmp"
check fingerprint-missing "$(fingerprint /no/such/file/here)" missing

# Path resolution: env override wins; otherwise state dir, then config dir.
check resolve-env-override "$(HERDR_CHECKLIST_FILE=/x/y.md resolve_file)" /x/y.md
check resolve-state-dir "$(unset HERDR_CHECKLIST_FILE; HERDR_PLUGIN_STATE_DIR=/s resolve_file)" /s/CHECKLIST.md

# Starter carries the owner and all four sections.
out=$(starter Cynthia)
for marker in "CHECKLIST — Cynthia" "🔴 ACT NOW" "🔵 IN FLIGHT" "🟡 WAITING" "🟢 RECENTLY DONE"; do
  case $out in
    *"$marker"*) printf 'ok   starter-has %s\n' "$marker" ;;
    *) printf 'FAIL starter-missing %s\n' "$marker"; fail=1 ;;
  esac
done

exit "$fail"
