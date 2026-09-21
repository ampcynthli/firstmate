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

poll_tmp=$(mktemp -d)
trap 'rm -rf "$poll_tmp"' EXIT
for failure in fingerprint render disappear-before-render disappear-after-render; do
  mkdir "$poll_tmp/$failure"
  printf 'initial\n' >"$poll_tmp/$failure/checklist.md"
  (
    export CHECKLIST_TEST_DIR="$poll_tmp/$failure" CHECKLIST_TEST_FAILURE="$failure"
    export HERDR_CHECKLIST_FILE="$poll_tmp/$failure/checklist.md"
    export HERDR_CHECKLIST_RENDERER=checklist_test_renderer
    cksum() {
      if [ "$CHECKLIST_TEST_FAILURE" = fingerprint ] && [ ! -f "$CHECKLIST_TEST_DIR/failed" ]; then
        touch "$CHECKLIST_TEST_DIR/failed"
        return 1
      fi
      command cksum "$@" || return
      if [ "$CHECKLIST_TEST_FAILURE" = disappear-before-render ] && [ ! -f "$CHECKLIST_TEST_DIR/failed" ]; then
        touch "$CHECKLIST_TEST_DIR/failed"
        mv "$HERDR_CHECKLIST_FILE" "$CHECKLIST_TEST_DIR/moved"
      fi
    }
    checklist_test_renderer() {
      if [ "$CHECKLIST_TEST_FAILURE" = render ] && [ ! -f "$CHECKLIST_TEST_DIR/failed" ]; then
        touch "$CHECKLIST_TEST_DIR/failed"
        return 1
      fi
      command cat "$@" >>"$CHECKLIST_TEST_DIR/rendered"
    }
    sleep() {
      checklist_test_polls=$((${checklist_test_polls:-0} + 1))
      if [ -f "$CHECKLIST_TEST_DIR/moved" ]; then
        mv "$CHECKLIST_TEST_DIR/moved" "$HERDR_CHECKLIST_FILE"
      fi
      case $checklist_test_polls in
        1)
          if [ "$CHECKLIST_TEST_FAILURE" = disappear-after-render ]; then
            mv "$HERDR_CHECKLIST_FILE" "$CHECKLIST_TEST_DIR/moved"
          fi
          ;;
        3) printf 'updated\n' >"$HERDR_CHECKLIST_FILE" ;;
        4) return 77 ;;
      esac
    }
    export -f cksum checklist_test_renderer sleep
    bash "$DIR/herdr-checklist.sh" view
  ) >"$poll_tmp/$failure/output" 2>&1
  check "view-$failure-keeps-polling" "$?" 77
  expected=$'initial\nupdated'
  if [ "$failure" = disappear-after-render ]; then
    expected=$'initial\ninitial\nupdated'
  fi
  check "view-$failure-retries-and-refreshes" "$(cat "$poll_tmp/$failure/rendered" 2>/dev/null)" "$expected"
  case $failure in
    disappear-*)
      case $(cat "$poll_tmp/$failure/output") in
        *"No checklist yet at $poll_tmp/$failure/checklist.md"*) check "view-$failure-placeholder-shown" yes yes ;;
        *) check "view-$failure-placeholder-shown" no yes ;;
      esac
      ;;
  esac
done

exit "$fail"
