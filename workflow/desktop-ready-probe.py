#!/usr/bin/env python3
"""Record readiness from the live session when its user unit was not started."""

import json
import os
import pathlib
import subprocess
import time


def session_processes():
    result = {"compositor": [], "shell": []}
    for entry in pathlib.Path("/proc").iterdir():
        if not entry.name.isdecimal():
            continue
        try:
            if entry.stat().st_uid != os.getuid():
                continue
            name = (entry / "comm").read_text().strip()
            args = (
                (entry / "cmdline")
                .read_bytes()
                .replace(b"\x00", b" ")
                .decode(errors="replace")
            )
        except (OSError, UnicodeError):
            continue
        if name in ("niri", "labwc"):
            result["compositor"].append(int(entry.name))
        if (
            "quickshell" in name
            or name == "qs"
            or args.startswith(("quickshell ", "qs "))
            or "/bin/qs " in args
        ):
            result["shell"].append(int(entry.name))
    return result


def shell_responds(pid):
    """Require a reply from this session's actual Quickshell configuration."""
    try:
        args = (pathlib.Path("/proc") / str(pid) / "cmdline").read_bytes()
        args = args.decode().strip("\x00").split("\x00")
        selector = []
        for index, argument in enumerate(args[:-1]):
            if argument in ("-p", "--path", "-c", "--config"):
                selector = [argument, args[index + 1]]
                break
        result = subprocess.run(
            ["quickshell", *selector, "ipc", "show"],
            capture_output=True,
            timeout=3,
            check=False,
        )
        return result.returncode == 0
    except (OSError, UnicodeError, subprocess.TimeoutExpired):
        return False


def main():
    runtime = pathlib.Path(
        os.environ.get("XDG_RUNTIME_DIR", f"/run/user/{os.getuid()}")
    )
    os.environ["XDG_RUNTIME_DIR"] = str(runtime)
    os.environ["DBUS_SESSION_BUS_ADDRESS"] = f"unix:path={runtime}/bus"
    environment = subprocess.run(
        ["systemctl", "--user", "show-environment"],
        capture_output=True,
        text=True,
        timeout=5,
        check=False,
    )
    for line in environment.stdout.splitlines():
        key, _, value = line.partition("=")
        if key in ("WAYLAND_DISPLAY", "DISPLAY"):
            os.environ[key] = value
    if "WAYLAND_DISPLAY" not in os.environ:
        sockets = [path for path in runtime.glob("wayland-*") if path.is_socket()]
        if sockets:
            os.environ["WAYLAND_DISPLAY"] = sockets[0].name
    marker = runtime / "desktop-ready"
    deadline = time.monotonic() + 30
    while time.monotonic() < deadline:
        # The compositor may create its display after this probe starts.
        sockets = [path for path in runtime.glob("wayland-*") if path.is_socket()]
        if sockets and os.environ.get("WAYLAND_DISPLAY") not in {
            path.name for path in sockets
        }:
            os.environ["WAYLAND_DISPLAY"] = sockets[0].name
        processes = session_processes()
        if (
            any(path.is_socket() for path in runtime.glob("wayland-*"))
            and processes["compositor"]
            and processes["shell"]
        ):
            time.sleep(1)
            if any(shell_responds(pid) for pid in session_processes()["shell"]):
                if not marker.is_file():
                    marker.write_text(
                        pathlib.Path("/proc/uptime").read_text().split()[0] + "\n"
                    )
                print(
                    json.dumps(
                        {"status": "ready", "processes": processes, "shellIpc": True}
                    )
                )
                return
        time.sleep(0.5)
    raise RuntimeError("The compositor and Quickshell IPC did not become ready")


if __name__ == "__main__":
    main()
