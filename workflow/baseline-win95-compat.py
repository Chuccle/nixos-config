#!/usr/bin/env python3
"""Start the unchanged labwc Win95 shell in a VMware baseline guest.

The original Qt Quick shell exits when VMware rejects its DMA-BUF import.
Qt's documented software scene graph uses shared-memory buffers while labwc
and the Wayland EGL renderer can continue to use the SVGA3D device.
"""

import json
import os
import pathlib
import shutil
import subprocess
import time


def main():
    runtime = pathlib.Path(os.environ["XDG_RUNTIME_DIR"])
    deadline = time.monotonic() + 30
    while time.monotonic() < deadline:
        if (runtime / "wayland-0").is_socket() and subprocess.run(
            ["pgrep", "-x", "labwc"], check=False, capture_output=True
        ).returncode == 0:
            break
        time.sleep(0.5)
    else:
        raise RuntimeError("The labwc Wayland socket did not become ready")

    if not shutil.which("quickshell"):
        raise RuntimeError("The baseline ISO has no Quickshell executable")
    environment = os.environ.copy()
    environment.update(
        WAYLAND_DISPLAY="wayland-0",
        QT_QPA_PLATFORM="wayland",
        QT_QUICK_BACKEND="software",
    )
    log = pathlib.Path("/tmp/baseline-win95-quickshell.log")
    with log.open("wb") as output:
        shell = subprocess.Popen(
            ["quickshell", "-c", "win95"],
            env=environment,
            stdin=subprocess.DEVNULL,
            stdout=output,
            stderr=subprocess.STDOUT,
            start_new_session=True,
        )
    time.sleep(3)
    if shell.poll() is not None:
        raise RuntimeError(f"Quickshell exited at startup; inspect {log}")
    uptime = pathlib.Path("/proc/uptime").read_text().split()[0]
    (runtime / "desktop-ready").write_text(uptime + "\n")
    print(
        json.dumps(
            {
                "status": "ready",
                "scope": "baseline-win95-vmware-only",
                "qtQuickBackend": "software",
                "shellPid": shell.pid,
                "log": str(log),
            }
        )
    )


if __name__ == "__main__":
    main()
