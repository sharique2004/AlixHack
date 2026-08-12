"""Vercel entry point — serves the FastAPI app as a Python (ASGI) function.

Two things differ from running locally, and both are handled here rather than
by branching inside the application code:

1. **The function filesystem is read-only.** `/var/task` cannot be chmod'ed, and
   `includeFiles` does not reliably preserve the executable bit. So on cold
   start each engine is made runnable — in place when that works, otherwise by
   copying it to `/tmp` (the only writable directory) and chmod'ing there.

2. **Paths.** `LEAN_BIN_DIR` and `STATIC_DIR` point the runners and the app at
   wherever the bundle actually put things, so `main.py` needs no knowledge of
   Vercel at all.

The engine is a ~95 MB native binary. It fits: Vercel's Python runtime allows
500 MB uncompressed per function (5 GB with large functions). The cost is cold
start — roughly a second or two while the binary is staged — which is why the
first request after an idle period is slower than the ~20 ms the engine itself
takes.
"""

from __future__ import annotations

import os
import shutil
import stat
import sys
from pathlib import Path

# The bundle root: this file is <root>/api/index.py.
ROOT = Path(__file__).resolve().parent.parent

# Make the application package importable exactly as it is locally.
sys.path.insert(0, str(ROOT / "demo" / "backend"))

BUNDLED_BIN = ROOT / "bin"
RUNTIME_BIN = Path("/tmp/atlas-bin")
ENGINES = ("probate-api", "settlement-api")


def _is_executable(path: Path) -> bool:
    return path.is_file() and os.access(path, os.X_OK)


def _stage_engines() -> Path:
    """Return a directory holding runnable engine binaries.

    Prefers the bundled copies untouched (fastest). Falls back to chmod in
    place, then to copying into /tmp. Returns the bundled directory unchanged
    if there is nothing to stage, so a misconfigured deploy surfaces as the
    runner's own clean 503 rather than an exception here.
    """
    present = [name for name in ENGINES if (BUNDLED_BIN / name).is_file()]
    if not present:
        return BUNDLED_BIN

    if all(_is_executable(BUNDLED_BIN / name) for name in present):
        return BUNDLED_BIN

    # Try to set the bit in place; /var/task is normally read-only.
    try:
        for name in present:
            target = BUNDLED_BIN / name
            target.chmod(target.stat().st_mode | stat.S_IXUSR | stat.S_IXGRP | stat.S_IXOTH)
        if all(_is_executable(BUNDLED_BIN / name) for name in present):
            return BUNDLED_BIN
    except OSError:
        pass

    # Read-only bundle: stage into the writable /tmp, once per cold start.
    try:
        RUNTIME_BIN.mkdir(parents=True, exist_ok=True)
        for name in present:
            dst = RUNTIME_BIN / name
            if not _is_executable(dst):
                shutil.copy2(BUNDLED_BIN / name, dst)
                dst.chmod(0o755)
        return RUNTIME_BIN
    except OSError:
        # Nothing more to try — let the runner report an unavailable engine.
        return BUNDLED_BIN


os.environ.setdefault("LEAN_BIN_DIR", str(_stage_engines()))
# The frontend is served by Vercel's static layer, not by FastAPI, so STATIC_DIR
# stays unset here and the app's catch-all never mounts.

from app.main import app  # noqa: E402  — after sys.path and env are prepared

__all__ = ["app"]
