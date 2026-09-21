"""Capture the existing lab helper's real Herdr PTY output without changing it."""
import os, runpy, sys
from pathlib import Path
if not sys.argv[1].endswith('/bin/fm-herdr-lab-viewer.py'):
    os.execv(sys.executable, [sys.executable] + sys.argv[1:])
module = runpy.run_path(sys.argv[1])
namespace = module['main'].__globals__
namespace['COLS'] = 200
namespace['ROWS'] = 42
def capture(master):
    with open(os.environ['CHECKLIST_TUI_CAPTURE'], 'wb', buffering=0) as output:
        while True:
            try:
                data = os.read(master, 65536)
            except InterruptedError:
                continue
            except OSError:
                return
            if not data:
                return
            output.write(data)
namespace['_drain'] = capture
raise SystemExit(module['main'](sys.argv[1:]))
