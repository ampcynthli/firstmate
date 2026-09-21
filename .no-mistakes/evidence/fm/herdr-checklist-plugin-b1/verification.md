# Herdr checklist validation

Tested commit: `2724489c1690126e2988a8d1f5b3452d43b49ae4`.

The existing focused shell suite passed. Running those same tests against the pre-snapshot implementation (`b073c24`) reproduced the disappearing-file and truncation regressions; the target implementation passes both.

The real Herdr 0.8.2 local-link workflow passed twice: with the default managed checklist path, and with a custom path containing spaces and an owner supplied in the server startup environment. Each run used a guarded, disposable named session and an isolated plugin registry inside the worktree. The running default session was used only for the helper's read-only safety check; its identity and running state were unchanged afterward.

Observed through public Herdr commands:
- Linking registers the manifest, `new` action, and split-pane entrypoint.
- The asynchronous action completes successfully; its plugin log reports the exact created file path.
- The generated file has the owner and all four sections.
- Opening the plugin displays that file in its dedicated pane, using the real `cat` fallback.
- Editing the checklist displays the reply-word, in-flight pane reference, waiting item, and completed item.
- Invoking `new` again preserves existing content.
- A same-length edit with its original modification timestamp restored still refreshes.
- Temporarily moving the source away preserves the current frame; restoring it and making another edit refreshes successfully.

`herdr-terminal.html` replays bytes recorded from an actual attached Herdr client through the existing lab PTY helper. The portable replay uses xterm.js and the original PTY bytes; it is not a reconstruction of the UI. Its browser rendering remains unverified because screenshot capture failed. The recording used a 200-column, 42-row terminal. `herdr-workflow.txt` and `custom/herdr-workflow.txt` contain the real commands and responses.

The first manual driver attempts were corrected for Herdr's mutually exclusive workspace/target-pane parameters and its nested pane response shape. These were test-driver setup errors, not plugin failures. No repository source files were changed. No broad suite, linter, formatter, or static analyzer was run. GitHub download installation and optional glow/mdcat/bat rendering were not exercised; local linking and dependency-free rendering were exercised end to end.

Visual limitation: chrome-devtools-axi returned `BRIDGE_NOT_READY`; direct headless Chrome timed out even when capturing `about:blank`, logging `CVDisplayLinkCreateWithCGDisplay failed` (CVReturn -6670). A native WebKit fallback could not compile because the installed Swift compiler and SDK report mismatched versions and duplicate SwiftBridging modules. No system configuration or packages were changed. The terminal recording should be opened and captured on a working graphical host before claiming visual verification.

Cleanup: both isolated Herdr sessions were stopped/deleted through the lab helper, the test browser was stopped, temporary worktree state was removed, and the running default Herdr session remained unchanged.
