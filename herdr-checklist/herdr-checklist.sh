#!/usr/bin/env bash
# herdr-checklist.sh - render a single markdown checklist file in a dedicated,
# auto-refreshing Herdr pane, and stand that pane up in one command.
#
# Subcommands:
#   view <file>    Long-running. Watch <file> and re-render it on every change.
#                  This is what runs inside the dedicated Herdr pane.
#   setup [opts]   Create the checklist file from the built-in starter (only if
#                  it does not exist yet), then open a dedicated Herdr pane
#                  running `view`. Always prints the manual recipe as a fallback.
#
# setup options:
#   --file <path>      checklist file (default: $HERDR_CHECKLIST_FILE or ./CHECKLIST.md)
#   --owner <name>     name written into the starter header (default: "you")
#   --direction <dir>  split direction: right (default) or down
#   --ratio <float>    split ratio passed through to `herdr pane split`
#
# Rendering: if glow, mdcat, or bat is on PATH it is used; otherwise plain cat.
# Override the choice with $HERDR_CHECKLIST_RENDERER (a program name).
# No required dependencies beyond bash and coreutils; jq is used only if present.
# The format the checklist file follows lives in checklist-template.md.

SELF="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/$(basename "${BASH_SOURCE[0]}")"
RENDERERS=(glow mdcat bat)

warn() { printf '%s\n' "$*" >&2; }
die() { warn "$*"; exit 1; }

# Portable mtime read (BSD/macOS stat, then GNU/Linux stat).
checklist_mtime() {
  stat -f %m "$1" 2>/dev/null || stat -c %Y "$1" 2>/dev/null
}

# Echo the renderer program to use: the override if set, else the first
# candidate found on PATH, else "cat".
pick_renderer() {
  if [ -n "${HERDR_CHECKLIST_RENDERER:-}" ]; then
    printf '%s\n' "$HERDR_CHECKLIST_RENDERER"
    return
  fi
  local c
  for c in "$@"; do
    if command -v "$c" >/dev/null 2>&1; then
      printf '%s\n' "$c"
      return
    fi
  done
  printf '%s\n' cat
}

clear_screen() { printf '\033[H\033[2J'; }

render() {
  local file=$1 renderer
  renderer=$(pick_renderer "${RENDERERS[@]}")
  clear_screen
  if [ ! -f "$file" ]; then
    printf 'No checklist yet at %s\n\nCreate one with:\n  %s setup --file %s\n' \
      "$file" "$SELF" "$file"
    return
  fi
  case $renderer in
    glow) glow -w "${COLUMNS:-100}" "$file" ;;
    bat) bat --style=plain --language=markdown --paging=never "$file" ;;
    cat) cat "$file" ;;
    *) "$renderer" "$file" ;;
  esac
}

# ponytail: 1s mtime poll instead of an inotify/fswatch dependency. A checklist
# changes a few times an hour, so the poll is invisible; swap in entr/fswatch
# only if you ever need sub-second latency.
view() {
  local file=${1:-} last="" now
  [ -n "$file" ] || die "usage: $SELF view <file>"
  while :; do
    now=$(checklist_mtime "$file" 2>/dev/null || printf 'missing')
    [ -n "$now" ] || now=missing
    if [ "$now" != "$last" ]; then
      last=$now
      render "$file"
    fi
    sleep "${HERDR_CHECKLIST_INTERVAL:-1}"
  done
}

# Emit a fresh, empty checklist in the format checklist-template.md defines.
starter() {
  local owner=${1:-you} now
  now=$(date '+%Y-%m-%d %H:%M')
  cat <<EOF
# CHECKLIST — $owner    $now local
# ════════════════════════════════════════════════════════════

## 🔴 ACT NOW — only you can do these

## 🔵 IN FLIGHT — agents working right now

## 🟡 WAITING — parked on a word or an external event

## 🟢 RECENTLY DONE
EOF
}

# Read the new pane id out of `herdr pane split` output (jq if present, else sed).
extract_pane_id() {
  local out=$1 id=""
  if command -v jq >/dev/null 2>&1; then
    id=$(printf '%s' "$out" | jq -r '.result.pane.pane_id // .result.pane_id // empty' 2>/dev/null)
  fi
  if [ -z "$id" ]; then
    id=$(printf '%s' "$out" | sed -n 's/.*"pane_id":"\([^"]*\)".*/\1/p' | head -n1)
  fi
  [ -n "$id" ] && printf '%s\n' "$id"
}

print_recipe() {
  local file=$1 dir
  dir=$(cd "$(dirname "$file")" && pwd)
  cat <<EOF

Manual setup (works in any Herdr session):
  1. Split a pane where you want the checklist:
       herdr pane split --current --direction right --cwd "$dir"
  2. Run the viewer in that new pane (use its pane id):
       $SELF view "$file"
Keep that pane open; it refreshes whenever $file changes.
EOF
}

open_pane() {
  local file=$1 direction=$2 ratio=$3 dir out pane_id
  dir=$(cd "$(dirname "$file")" && pwd)
  local -a split=(pane split --current --direction "$direction" --cwd "$dir")
  [ -n "$ratio" ] && split+=(--ratio "$ratio")
  out=$(herdr "${split[@]}" 2>&1) || { warn "herdr pane split failed: $out"; return 1; }
  pane_id=$(extract_pane_id "$out")
  [ -n "$pane_id" ] || { warn "could not read a new pane id from: $out"; return 1; }
  herdr pane run "$pane_id" "$SELF" view "$file" || { warn "herdr pane run failed"; return 1; }
  printf 'Opened checklist pane %s viewing %s\n' "$pane_id" "$file"
}

setup() {
  local file=${HERDR_CHECKLIST_FILE:-CHECKLIST.md} owner=you direction=right ratio=""
  while [ $# -gt 0 ]; do
    case $1 in
      --file) file=${2:?--file needs a path}; shift 2 ;;
      --owner) owner=${2:?--owner needs a name}; shift 2 ;;
      --direction) direction=${2:?--direction needs right|down}; shift 2 ;;
      --ratio) ratio=${2:?--ratio needs a number}; shift 2 ;;
      *) die "setup: unknown option $1" ;;
    esac
  done

  if [ -e "$file" ]; then
    printf 'Using existing checklist %s\n' "$file"
  else
    starter "$owner" >"$file"
    printf 'Created %s\n' "$file"
  fi

  if [ "${HERDR_ENV:-}" = "1" ] && command -v herdr >/dev/null 2>&1; then
    open_pane "$file" "$direction" "$ratio" || print_recipe "$file"
  else
    warn "Not inside a Herdr pane (HERDR_ENV != 1); showing the manual recipe."
    print_recipe "$file"
  fi
}

usage() {
  sed -n '2,22p' "$SELF" | sed 's/^# \{0,1\}//'
}

main() {
  set -euo pipefail
  case ${1:-} in
    view) shift; view "$@" ;;
    setup) shift; setup "$@" ;;
    ""|-h|--help|help) usage ;;
    *) die "unknown subcommand: $1 (try: view, setup, --help)" ;;
  esac
}

if [ "${BASH_SOURCE[0]}" = "${0}" ]; then
  main "$@"
fi
