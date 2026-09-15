# Herdr checklist

A single markdown file, rendered in a dedicated [Herdr](https://herdr.dev) pane, that gives you one at-a-glance view of everything in flight: what only you can unblock, what your agents are running, what is parked, and what just landed.

It is a convention plus a tiny viewer, not a heavy plugin.
Herdr has no third-party plugin API, so this ships as a standalone script that drives Herdr's pane CLI (`herdr pane split` / `herdr pane run`).

## What it looks like

```
# CHECKLIST — you                                 2026-09-15 14:22 local
# ════════════════════════════════════════════════════════════

## 🔴 ACT NOW — only you can do these
1. Paste the API key into the deploy config — unblocks the staging release.
   reply-word: "keyed"

## 🔵 IN FLIGHT — agents working right now
- Refactor the auth module (pane w3:p2). Done = green PR.

## 🟡 WAITING — parked on a word or an external event
- Design review: waiting on Sam's reply in the thread.

## 🟢 RECENTLY DONE
- Merged the logging fix: https://github.com/acme/app/pull/812
```

The four sections, the placement rules, and the invariants that keep the file trustworthy (every thread appears exactly once, nothing is dropped silently, reply-words are load-bearing) are the actual value here.
They live in [checklist-template.md](checklist-template.md) — read that; it is the contract you (and any agent maintaining the file for you) follow on every edit.

## Install (under 5 minutes)

1. Copy this directory anywhere on the machine where you run Herdr, and make the script executable:

   ```sh
   chmod +x herdr-checklist.sh
   ```

2. From inside a Herdr pane, create the checklist and open its viewer pane in one command:

   ```sh
   ./herdr-checklist.sh setup --owner "Your Name"
   ```

   That writes `CHECKLIST.md` (if it does not exist), splits a pane to the right, and starts the auto-refreshing viewer there.
   Pass `--file path/to/CHECKLIST.md` to put it elsewhere, or `--direction down` / `--ratio 0.3` to change the split.

3. Keep that pane open. It re-renders whenever the file changes — no restart needed.

Not inside Herdr, or want to place the pane by hand? `setup` prints the manual recipe, which is just `herdr pane split` followed by `herdr-checklist.sh view <file>` in the new pane.

## Rendering

The viewer uses [`glow`](https://github.com/charmbracelet/glow), `mdcat`, or `bat` if any is installed, and falls back to plain `cat` otherwise — nothing extra is required.
Force a choice with `HERDR_CHECKLIST_RENDERER=glow`.

## Keeping it useful

The point is that the file always reflects reality.
Edit it surgically as state changes; do a full rewrite only when the structure drifts, and when you do, diff against the previous version so nothing live disappears without a reason.
If an AI agent maintains the file for you, point it at [checklist-template.md](checklist-template.md) and have it re-read that contract after any context reset.

## Tests

```sh
./herdr-checklist.test.sh
```

Covers renderer selection, change detection, and the starter skeleton.
