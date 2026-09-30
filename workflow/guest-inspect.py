#!/usr/bin/env python3
"""Live-session inspection. Evidence is recorded, never inferred from a build."""

import argparse
import errno
import glob
import hashlib
import json
import os
import pathlib
import signal
import shlex
import shutil
import subprocess
import time
import traceback
import zipfile


def command(*args, timeout=20, check=True):
    result = subprocess.run(
        list(args), text=True, capture_output=True, timeout=timeout, check=False
    )
    if check and result.returncode:
        raise RuntimeError(
            f"{args!r}: {result.stderr.strip() or result.stdout.strip()}"
        )
    return result.stdout


def session_environment():
    runtime = f"/run/user/{os.getuid()}"
    os.environ["XDG_RUNTIME_DIR"] = runtime
    os.environ["DBUS_SESSION_BUS_ADDRESS"] = f"unix:path={runtime}/bus"
    for line in command("systemctl", "--user", "show-environment").splitlines():
        key, _, value = line.partition("=")
        if key in ("NIRI_SOCKET", "WAYLAND_DISPLAY", "DISPLAY", "XDG_CURRENT_DESKTOP"):
            os.environ[key] = value
    if "NIRI_SOCKET" not in os.environ:
        sockets = glob.glob(f"{runtime}/niri.*.sock")
        if sockets:
            os.environ["NIRI_SOCKET"] = sockets[0]
    if "WAYLAND_DISPLAY" not in os.environ:
        sockets = [
            p for p in glob.glob(f"{runtime}/wayland-*") if not p.endswith(".lock")
        ]
        if sockets:
            os.environ["WAYLAND_DISPLAY"] = pathlib.Path(sockets[0]).name


def niri(query):
    return json.loads(command("niri", "msg", "--json", query))


def action(*args):
    return command("niri", "msg", "action", *map(str, args))


def cpu_ticks(text):
    ticks = [int(value) for value in text.splitlines()[0].split()[1:9]]
    return sum(ticks), ticks[3] + ticks[4]


def cpu_percent(before, after):
    total, idle = after[0] - before[0], after[1] - before[1]
    return 100 * (total - idle) / total if total else 0.0


def used_memory(text):
    fields = {line.split(":")[0]: int(line.split()[1]) for line in text.splitlines()}
    return (fields["MemTotal"] - fields["MemAvailable"]) * 1024


def process_memory(root=pathlib.Path("/proc")):
    processes = []
    for directory in root.iterdir():
        if not directory.name.isdigit():
            continue
        try:
            fields = {}
            for line in (directory / "status").read_text().splitlines():
                key, _, value = line.partition(":")
                if key in ("Name", "VmRSS"):
                    fields[key] = value.strip()
            if "VmRSS" not in fields:
                continue
            processes.append(
                {
                    "pid": int(directory.name),
                    "name": fields.get("Name", "unknown"),
                    "rssBytes": int(fields["VmRSS"].split()[0]) * 1024,
                }
            )
        except (FileNotFoundError, PermissionError, ProcessLookupError, ValueError):
            continue
    return sorted(processes, key=lambda process: process["rssBytes"], reverse=True)


def summarize_process_memory(snapshots):
    totals = {}
    for snapshot in snapshots:
        for process in snapshot["top"]:
            key = (process["pid"], process["name"])
            entry = totals.setdefault(
                key,
                {
                    "pid": process["pid"],
                    "name": process["name"],
                    "samples": 0,
                    "totalRssBytes": 0,
                    "peakRssBytes": 0,
                },
            )
            entry["samples"] += 1
            entry["totalRssBytes"] += process["rssBytes"]
            entry["peakRssBytes"] = max(entry["peakRssBytes"], process["rssBytes"])
    return sorted(
        (
            {
                "pid": entry["pid"],
                "name": entry["name"],
                "samples": entry["samples"],
                "averageRssBytes": entry["totalRssBytes"] / entry["samples"],
                "peakRssBytes": entry["peakRssBytes"],
            }
            for entry in totals.values()
        ),
        key=lambda entry: entry["averageRssBytes"],
        reverse=True,
    )[:20]


def wait_for(predicate, seconds=20):
    deadline = time.monotonic() + seconds
    while time.monotonic() < deadline:
        value = predicate()
        if value:
            return value
        time.sleep(0.2)
    raise RuntimeError("Timed out waiting for the expected desktop state")


class Inspection:
    def __init__(self, args):
        self.args = args
        self.directory = pathlib.Path(args.output)
        self.directory.mkdir(parents=True, exist_ok=True)
        self.checks = []
        self.counter = 0
        self.input_available = False
        self.current_resolution = ""

    def save(self, name, value):
        path = self.directory / name
        path.write_text(json.dumps(value, indent=2) + "\n")
        return path.name

    def capture(self, name):
        if self.current_resolution:
            name = f"{name}-{self.current_resolution}"
        path = self.directory / f"{name}.png"
        action("screenshot-screen", "--path", path, "--show-pointer", "false")

        def complete_png():
            if not path.exists() or path.stat().st_size < 12:
                return False
            with path.open("rb") as image:
                image.seek(-12, os.SEEK_END)
                return image.read() == b"\x00\x00\x00\x00IEND\xaeB`\x82"

        wait_for(complete_png)
        self.save(f"{name}-windows.json", niri("windows"))
        return path.name

    def check(self, name, procedure):
        try:
            evidence = procedure() or []
            self.checks.append(
                dict(id=name, status="pass", evidence=evidence, reason="Observed")
            )
        except Exception as error:
            diagnostic = self.directory / f"{name}-error.txt"
            diagnostic.write_text(traceback.format_exc())
            self.checks.append(
                dict(
                    id=name,
                    status="fail",
                    evidence=[diagnostic.name],
                    reason=str(error),
                )
            )
        self.save(
            "functional.json", dict(edition=self.args.edition, checks=self.checks)
        )

    def input_action(self, *actions):
        if not self.input_available:
            raise RuntimeError("Guest input service is unavailable")
        deadline = time.monotonic() + 5
        while True:
            try:
                descriptor = os.open(
                    os.environ["DOTOOL_PIPE"], os.O_WRONLY | os.O_NONBLOCK
                )
                break
            except OSError as error:
                if (
                    error.errno not in (errno.ENOENT, errno.ENXIO)
                    or time.monotonic() >= deadline
                ):
                    raise
                time.sleep(0.05)
        with os.fdopen(descriptor, "w") as pipe:
            pipe.write("\n".join(actions) + "\n")
        time.sleep(0.1)

    def key(self, *codes):
        self.input_action(
            *(f"keydown k:{code}" for code in codes),
            *(f"keyup k:{code}" for code in reversed(codes)),
        )
        time.sleep(0.4)

    def move_pointer(self, x, y):
        logical = next(iter(niri("outputs").values()))["logical"]
        self.input_action(f"mouseto {x / logical['width']} {y / logical['height']}")

    def click(self, x, y, button="left"):
        self.move_pointer(x, y)
        self.input_action(f"click {button}")
        time.sleep(0.4)

    def app(self, binary, *args):
        before = {w["id"] for w in niri("windows")}
        action("spawn", "--", binary, *args)
        window = wait_for(
            lambda: next(
                (
                    w
                    for w in niri("windows")
                    if w["id"] not in before
                    and binary.lower() in (w.get("app_id", "") or "").lower()
                ),
                None,
            ),
            40,
        )
        action("focus-window", "--id", window["id"])
        wait_for(lambda: self.find(window["id"])["is_focused"])
        return window

    def find(self, window_id):
        return next((w for w in niri("windows") if w["id"] == window_id), None)

    def clear(self):
        if not os.environ.get("NIRI_SOCKET"):
            return  # The unchanged Win95 baseline uses labwc and starts no apps.
        deadline = time.monotonic() + 30
        last_closed = {}
        while time.monotonic() < deadline:
            windows = niri("windows")
            if not windows:
                time.sleep(1)
                if not niri("windows"):
                    return
            for window in windows:
                if time.monotonic() - last_closed.get(window["id"], 0) > 1:
                    action("close-window", "--id", window["id"])
                    last_closed[window["id"]] = time.monotonic()
            time.sleep(0.2)
        raise RuntimeError("Applications did not close to a stable empty desktop")

    def window_command(self, verb, window_id=None):
        args = ["win95-window-action", verb]
        if window_id is not None:
            args.append(str(window_id))
        return json.loads(command(*args))

    def shell_state(self):
        output_name = next(iter(niri("outputs")))
        return json.loads(
            command(
                "quickshell",
                "-c",
                "win95",
                "ipc",
                "call",
                f"win95-{output_name}",
                "state",
            )
        )

    def fixtures(self):
        root = self.directory / (
            f"files-{self.current_resolution}" if self.current_resolution else "files"
        )
        root.mkdir(exist_ok=True)
        (root / "readme.txt").write_text("Desktop file operation fixture\n")
        with zipfile.ZipFile(root / "fixture.zip", "w") as archive:
            archive.write(root / "readme.txt", "readme.txt")
        (root / "browser.html").write_text(
            '<!doctype html><meta charset="utf-8"><title>Desktop rendering check</title>'
            "<style>body{font:24px sans-serif;margin:48px}button{font:inherit}"
            ".grid{display:grid;grid-template-columns:repeat(3,1fr);gap:10px}"
            ".grid div{color:white;padding:20px}"
            ".grid div:nth-child(1){background:#c00000}"
            ".grid div:nth-child(2){background:#008000}"
            ".grid div:nth-child(3){background:#0000c0}</style>"
            "<h1>Desktop rendering check</h1><p>Readable text: £ € ✓</p>"
            '<div class="grid"><div>Red</div><div>Green</div><div>Blue</div></div>'
            '<p><input value="Keyboard input"><button onclick="this.textContent=\'Clicked\'">Click</button></p>'
        )
        return root

    def launchers(self):
        desktop_files = []
        for directory in os.environ.get(
            "XDG_DATA_DIRS", "/run/current-system/sw/share"
        ).split(":"):
            desktop_files.extend(glob.glob(f"{directory}/applications/*.desktop"))
        text = "\n".join(
            pathlib.Path(p).read_text(errors="replace") for p in desktop_files
        )
        missing = [
            name
            for name in ("ghostty", "dolphin", "ark", "helium", "ida")
            if name not in text.lower()
        ]
        self.save("launchers.json", dict(files=desktop_files, missing=missing))
        if missing:
            raise RuntimeError(f"Missing desktop launchers: {missing}")
        evidence = ["launchers.json"]
        results = []
        for query in ("Ghostty", "Dolphin", "Ark", "Helium", "IDA"):
            try:
                evidence.extend(self.activate_launcher(query))
                results.append(dict(application=query, status="pass"))
            except Exception as error:
                results.append(
                    dict(application=query, status="fail", reason=str(error))
                )
                evidence.append(self.capture(f"launcher-failure-{query.lower()}"))
            finally:
                self.key(1)
                self.clear()
        evidence.append(self.save("launcher-results.json", results))
        failures = [result for result in results if result["status"] != "pass"]
        if failures:
            raise RuntimeError(f"Launcher activation failed: {failures}")
        return evidence

    def activate_launcher(self, query):
        self.clear()
        evidence = []
        before = {w["id"] for w in niri("windows")}
        if self.args.edition == "win95":
            self.clear()
            height = next(iter(niri("outputs").values()))["logical"]["height"]
            self.click(35, height - 16)
            wait_for(lambda: self.shell_state()["menuOpen"])
            state = self.shell_state()
            evidence.append(self.save(f"launcher-menu-{query.lower()}.json", state))
            index = next(
                i
                for i, entry in enumerate(state["entries"])
                if query.lower() in entry["name"].lower()
            )
            for _ in range(index):
                self.key(108)
            evidence.append(self.capture(f"launcher-query-{query.lower()}"))
            self.key(28)
        if self.args.edition == "tahoe":
            command("dms", "ipc", "call", "spotlight", "toggle")
            time.sleep(0.5)
            self.key(29, 30)  # Ctrl+A selects any remembered query.
            self.input_action(f"type {query}")
            time.sleep(1)
            evidence.append(self.capture(f"launcher-query-{query.lower()}"))
            self.key(108)  # Down and Up exercise result navigation.
            self.key(103)
            self.key(28)
        selected = wait_for(
            lambda: next(
                (
                    w
                    for w in niri("windows")
                    if w["id"] not in before
                    and query.lower() in (w.get("app_id", "") or "").lower()
                ),
                None,
            )
        )
        if not selected["is_focused"]:
            raise RuntimeError(f"Keyboard launcher activation did not focus {query}")
        evidence.append(self.capture(f"launcher-activation-{query.lower()}"))
        evidence.append(
            self.save(
                f"launcher-keyboard-{query.lower()}.json",
                dict(query=query, activatedWindow=selected),
            )
        )
        return evidence

    def appearances(self, resolution):
        original = command("dms", "ipc", "call", "theme", "getMode").strip()
        evidence = []
        observed = []
        try:
            for mode in ("light", "dark"):
                self.clear()
                command("dms", "ipc", "call", "theme", mode)
                wait_for(
                    lambda: command("dms", "ipc", "call", "theme", "getMode").strip()
                    == mode
                )
                time.sleep(1)
                observed.append(mode)
                evidence.append(self.capture(f"appearance-{mode}-{resolution}"))
                command("dms", "ipc", "call", "spotlight", "toggle")
                time.sleep(1)
                evidence.append(
                    self.capture(f"appearance-{mode}-launcher-{resolution}")
                )
                self.key(1)
                self.app("ghostty")
                evidence.append(self.capture(f"appearance-{mode}-ghostty-{resolution}"))
        finally:
            self.clear()
            if original in ("light", "dark"):
                command("dms", "ipc", "call", "theme", original)
        evidence.append(
            self.save(
                f"appearance-{resolution}.json",
                dict(original=original, observed=observed, restored=original),
            )
        )
        return evidence

    def applications(self):
        root = self.fixtures()
        applications = [
            ("ghostty", "ghostty", []),
            ("dolphin", "dolphin", [str(root)]),
            ("ark", "ark", [str(root / "fixture.zip")]),
            ("helium", "helium", ["--no-first-run", f"file://{root}/browser.html"]),
            ("ida", "ida", []),
        ]
        for name, binary, arguments in applications:

            def launch(name=name, binary=binary, arguments=arguments):
                if name == "ida" and not shutil.which(binary):
                    binary = next(
                        (p for p in ("ida64", "ida-pro") if shutil.which(p)), binary
                    )
                window = self.app(binary, *arguments)
                time.sleep(2)
                picture = self.capture(f"app-{name}")
                if not window.get("title"):
                    raise RuntimeError(f"{name} opened without a usable window title")
                self.clear()
                return [picture, f"{pathlib.Path(picture).stem}-windows.json"]

            self.check(f"launch-{name}", launch)

        def file_operations():
            self.app("dolphin", str(root))
            self.key(29, 42, 49)
            self.input_action("type Created by inspection")
            self.key(28)
            wait_for(lambda: (root / "Created by inspection").is_dir())
            picture = self.capture("file-created")
            self.clear()
            self.app("ark", str(root / "fixture.zip"))
            time.sleep(2)  # Wait for the archive plugin to populate its action menu.
            self.key(29, 18)  # Ark's Extract shortcut opens a destination dialog.
            dialog = wait_for(
                lambda: next(
                    (
                        w
                        for w in niri("windows")
                        if "extract" in w.get("title", "").lower()
                    ),
                    None,
                )
            )
            self.save("archive-dialog-window.json", dialog)
            picture2 = self.capture("archive-extract-dialog")
            self.key(1)
            self.clear()
            extracted = root / "extracted"
            extracted.mkdir()
            command(
                "ark",
                "--batch",
                "--destination",
                str(extracted),
                str(root / "fixture.zip"),
                timeout=60,
            )
            wait_for(lambda: (extracted / "readme.txt").exists())
            if (extracted / "readme.txt").read_text() != (
                root / "readme.txt"
            ).read_text():
                raise RuntimeError("Ark extracted content did not match its input")
            result = self.save(
                "archive-extraction.json",
                {
                    "input": str(root / "fixture.zip"),
                    "output": str(extracted / "readme.txt"),
                    "matched": True,
                },
            )
            return [picture, picture2, result]

        self.check("file-operations-and-archive-dialog", file_operations)

    def ida_dependencies(self):
        executable = shutil.which("ida")
        if not executable:
            raise RuntimeError("IDA executable is missing")
        package = pathlib.Path(executable).resolve().parents[2]
        install = pathlib.Path(
            os.environ.get(
                "IDA_INSPECTION_INSTALL_DIR", str(package / "opt" / "ida-pro")
            )
        )
        if not install.is_dir():
            raise RuntimeError(f"IDA installation is missing: {install}")
        linked = {}
        unresolved = {}
        for item in install.rglob("*"):
            if not item.is_file() or item.is_symlink():
                continue
            kind = command("file", "-b", str(item), check=False)
            if "ELF" not in kind or "x86-64" not in kind:
                continue
            result = subprocess.run(
                ["ldd", str(item)], text=True, capture_output=True, timeout=15
            )
            for line in (result.stdout + result.stderr).splitlines():
                if "/nix/store/" in line:
                    linked.setdefault(str(item.relative_to(install)), []).append(
                        line.strip()
                    )
                if "not found" in line or "version `" in line:
                    unresolved.setdefault(str(item.relative_to(install)), []).append(
                        line.strip()
                    )
        link_evidence = self.save(
            "ida-link-time.json", {"nixDependencies": linked, "unresolved": unresolved}
        )
        if unresolved:
            raise RuntimeError("IDA has unresolved link-time libraries")

        trace = self.directory / "ida-openat.log"
        process = subprocess.Popen(
            ["strace", "-f", "-e", "trace=openat", "-o", str(trace), "ida"],
            stdout=subprocess.DEVNULL,
            stderr=subprocess.DEVNULL,
            start_new_session=True,
        )
        time.sleep(8)
        if process.poll() is None:
            os.killpg(process.pid, signal.SIGTERM)
        try:
            process.wait(timeout=5)
        except subprocess.TimeoutExpired:
            os.killpg(process.pid, signal.SIGKILL)
            process.wait(timeout=5)
        runtime = sorted(
            {
                line.strip()
                for line in trace.read_text(errors="replace").splitlines()
                if ".so" in line and "/nix/store/" in line
            }
        )
        runtime_evidence = self.save(
            "ida-runtime-dlopens.json",
            {"openatLines": runtime, "trace": trace.name},
        )
        if not runtime:
            raise RuntimeError("IDA produced no traced Nix library opens")
        self.clear()
        return [link_evidence, runtime_evidence, trace.name]

    def ida_functionality(self):
        executable = shutil.which("ida")
        fixture_binary = shutil.which("true")
        if not executable or not fixture_binary:
            raise RuntimeError("IDA or the ELF fixture executable is unavailable")
        fixture = self.directory / "ida-fixture-true"
        shutil.copyfile(fixture_binary, fixture)
        if fixture.read_bytes()[:4] != b"\x7fELF":
            raise RuntimeError("The IDA analysis fixture is not an ELF file")
        database = self.directory / "ida-fixture.i64"
        digest = hashlib.sha256(fixture.read_bytes()).hexdigest()
        evidence = []
        results = []
        for mode in ("analyze", "reopen"):
            result_path = self.directory / f"ida-{mode}.json"
            log_path = self.directory / f"ida-{mode}.log"
            environment = os.environ.copy()
            environment.update(
                IDA_INSPECTION_MODE=mode,
                IDA_INSPECTION_OUTPUT=str(result_path),
                IDA_INSPECTION_DATABASE=str(database),
            )
            target = fixture if mode == "analyze" else database
            script = os.environ.get(
                "IDA_INSPECTION_SCRIPT", "/etc/desktop-ida-functional.py"
            )
            arguments = [executable, "-A", f"-S{script}"]
            if mode == "analyze":
                arguments.append(f"-o{database}")
            arguments.append(str(target))
            try:
                completed = subprocess.run(
                    arguments,
                    env=environment,
                    text=True,
                    stdout=subprocess.PIPE,
                    stderr=subprocess.STDOUT,
                    timeout=180,
                    check=False,
                )
                log_path.write_text(completed.stdout)
            except subprocess.TimeoutExpired as error:
                log_path.write_text(str(error))
                raise RuntimeError(f"IDA {mode} timed out; see {log_path.name}")
            evidence.extend((result_path.name, log_path.name))
            if not result_path.exists():
                diagnostic = log_path.read_text(errors="replace").strip().splitlines()
                detail = diagnostic[-1] if diagnostic else "IDA printed no diagnostic"
                raise RuntimeError(
                    f"IDA {mode} produced no IDAPython result: {detail}; see {log_path.name}"
                )
            result = json.loads(result_path.read_text())
            if completed.returncode or result.get("status") != "pass":
                raise RuntimeError(
                    f"IDA {mode} failed: {result.get('reason', completed.returncode)}"
                )
            results.append(result)
            if mode == "analyze" and (
                not database.exists() or not database.stat().st_size
            ):
                raise RuntimeError("IDA reported success but saved no database")
        if results[1]["functionCount"] < results[0]["functionCount"]:
            raise RuntimeError("Reopening the IDA database lost analyzed functions")
        if results[1]["examples"][0] != results[0]["examples"][0]:
            raise RuntimeError("Reopening the IDA database changed its disassembly")
        evidence.append(
            self.save(
                "ida-analysis-roundtrip.json",
                {
                    "fixtureSha256": digest,
                    "databaseSha256": hashlib.sha256(database.read_bytes()).hexdigest(),
                    "analyze": results[0],
                    "reopen": results[1],
                },
            )
        )
        self.clear()
        return evidence

    def win95(self):
        def fixture():
            self.clear()
            self.window_command("state")
            action("focus-workspace", "desktop")
            first = self.app("ghostty", "--title=First inspection window")
            second = self.app("ghostty", "--title=Second inspection window")
            return first["id"], second["id"]

        def floating():
            first_id, second_id = fixture()
            if not all(w["is_floating"] for w in niri("windows")):
                raise RuntimeError("Applications did not open floating")
            action("move-floating-window", "--id", first_id, "-x", "100", "-y", "100")
            action("move-floating-window", "--id", second_id, "-x", "160", "-y", "160")
            return [self.capture("overlapping-windows")]

        self.check("floating-overlap", floating)

        def hide_restore():
            first_id, _ = fixture()
            action("focus-window", "--id", first_id)
            original = self.find(first_id)
            self.window_command("hide", first_id)
            wait_for(
                lambda: self.find(first_id)["workspace_id"] != original["workspace_id"]
            )
            if self.find(first_id)["is_focused"]:
                raise RuntimeError(
                    "Hide followed the window into the parking workspace"
                )
            hidden = self.capture("taskbar-hidden")
            # Locate the actual delegate by niri ID, then exercise real input.
            output = next(iter(niri("outputs").values()))
            height = output["logical"]["height"]
            shell = self.shell_state()
            button = wait_for(
                lambda: next(
                    (
                        b
                        for b in self.shell_state()["buttons"]
                        if b["id"] == first_id and b["x"] is not None
                    ),
                    None,
                )
            )
            self.click(int(button["x"]), int(height - shell["taskbarHeight"] / 2))
            wait_for(
                lambda: self.find(first_id)["workspace_id"] == original["workspace_id"]
            )
            restored = self.find(first_id)
            if not restored["is_focused"]:
                raise RuntimeError("Taskbar restore did not focus the window")
            expected = original["layout"]["window_size"]
            actual = restored["layout"]["window_size"]
            if any(abs(a - b) > 3 for a, b in zip(expected, actual)):
                raise RuntimeError(f"Restore changed geometry: {expected} -> {actual}")
            return [hidden, self.capture("taskbar-restored")]

        self.check("taskbar-hide-restore-geometry", hide_restore)

        def maximize():
            _, second_id = fixture()
            action("focus-window", "--id", second_id)
            original = self.find(second_id)["layout"]["window_size"]
            self.window_command("maximize", second_id)
            time.sleep(0.3)
            large = self.find(second_id)["layout"]["window_size"]
            if large[0] <= original[0]:
                raise RuntimeError("Maximize did not increase window width")
            picture = self.capture("maximized")
            self.window_command("maximize", second_id)
            restored = self.find(second_id)["layout"]["window_size"]
            if any(abs(a - b) > 3 for a, b in zip(original, restored)):
                raise RuntimeError("Maximize toggle did not restore window size")
            return [picture]

        self.check("maximize-restore", maximize)

        def show_desktop():
            first_id, second_id = fixture()
            self.window_command("hide", first_id)
            self.window_command("show-desktop")
            parked = self.window_command("state")["parked"]
            if set(parked) != {first_id, second_id}:
                raise RuntimeError(f"Show Desktop tracked wrong windows: {parked}")
            picture = self.capture("show-desktop")
            self.window_command("show-desktop")
            if self.window_command("state")["parked"] != [first_id]:
                raise RuntimeError(
                    "Show Desktop restored an individually hidden window"
                )
            self.window_command("restore", first_id)
            return [picture, self.capture("show-desktop-restored")]

        self.check("show-desktop-independent-hides", show_desktop)

        def recovery():
            first_id, _ = fixture()
            original = self.find(first_id)
            self.window_command("hide", first_id)
            command("systemctl", "--user", "restart", "win95-shell.service")
            time.sleep(1)
            self.window_command("restore", first_id)
            if self.find(first_id)["workspace_id"] != original["workspace_id"]:
                raise RuntimeError("Shell restart lost the original workspace")
            return [self.capture("restart-recovery")]

        self.check("restart-recovery", recovery)

        def interrupted():
            first_id, _ = fixture()
            original = self.find(first_id)
            process = subprocess.Popen(
                ["win95-window-action", "hide", str(first_id)],
                stdout=subprocess.DEVNULL,
            )
            time.sleep(0.04)
            process.kill()
            process.wait()
            self.window_command("restore", first_id)
            if self.find(first_id)["workspace_id"] != original["workspace_id"]:
                raise RuntimeError("Interrupted hide could not be reconciled")
            action("close-window", "--id", first_id)
            wait_for(lambda: not self.find(first_id))
            state = self.window_command("state")
            if first_id in state["parked"]:
                raise RuntimeError("Closed window left stale parking state")
            rejected = subprocess.run(
                ["win95-window-action", "hide", str(first_id)], capture_output=True
            )
            if rejected.returncode == 0:
                raise RuntimeError("Stale window ID was accepted")
            return [self.save("recovery-state.json", state)]

        self.check("interrupted-commands-stale-ids", interrupted)

        def input_controls():
            first_id, second_id = fixture()
            third = self.app("ghostty", "--title=Keyboard inspection")
            self.key(56, 15)  # Alt+Tab
            if self.find(third["id"])["is_focused"]:
                raise RuntimeError("Alt+Tab did not switch focus")
            focused = next(w["id"] for w in niri("windows") if w["is_focused"])
            self.key(56, 62)  # Alt+F4
            wait_for(lambda: not self.find(focused))
            remaining = niri("windows")[0]
            action("focus-window", "--id", remaining["id"])
            position = remaining["layout"]["tile_pos_in_workspace_view"]
            x, y = int(position[0] + 40), int(position[1] + 40)
            self.move_pointer(x, y)
            self.input_action("keydown k:125", "buttondown left")
            self.input_action("mousemove 80 40")
            self.input_action("buttonup left", "keyup k:125")
            moved = self.find(remaining["id"])
            if moved["layout"]["tile_pos_in_workspace_view"] == position:
                raise RuntimeError("Super+left drag did not move the window")
            size = moved["layout"]["window_size"]
            self.input_action("keydown k:125", "buttondown right")
            self.input_action("mousemove 50 30")
            self.input_action("buttonup right", "keyup k:125")
            if self.find(remaining["id"])["layout"]["window_size"] == size:
                raise RuntimeError("Super+right drag did not resize the window")
            return [self.capture("mouse-keyboard-controls")]

        self.check("drag-resize-alt-tab-alt-f4", input_controls)
        self.clear()

    def suite(self):
        try:
            command("sudo", "systemctl", "start", "desktop-test-input.service")
            os.environ["DOTOOL_PIPE"] = "/run/desktop-test-input/input.pipe"
            wait_for(lambda: pathlib.Path(os.environ["DOTOOL_PIPE"]).exists())
            self.input_available = True
            self.input_action(
                "keydelay 80", "keyhold 80", "typedelay 20", "typehold 20"
            )
            self.clear()
            output_name = next(iter(niri("outputs")))
            initial_resolution = self.args.resolutions[0]
            command("niri", "msg", "output", output_name, "mode", initial_resolution)
            width, height = map(int, initial_resolution.split("x"))
            wait_for(
                lambda: niri("outputs")[output_name]["logical"]["width"] == width
                and niri("outputs")[output_name]["logical"]["height"] == height
            )
            self.check("application-launchers", self.launchers)
            self.check("ida-dependency-closure", self.ida_dependencies)
            self.check("ida-analysis-roundtrip", self.ida_functionality)
            self.applications()
            if self.args.edition == "win95":
                self.win95()

                def shutdown_confirmation():
                    output = next(iter(niri("outputs").values()))
                    height = output["logical"]["height"]
                    self.click(35, height - 16)
                    wait_for(lambda: self.shell_state()["menuOpen"])
                    self.save("start-menu-state.json", self.shell_state())
                    menu = self.capture("start-menu")
                    self.click(130, height - 66)
                    wait_for(lambda: self.shell_state()["confirmationVisible"])
                    confirmation = self.capture("shutdown-confirmation")
                    self.key(1)
                    self.key(1)
                    wait_for(
                        lambda: not self.shell_state()["confirmationVisible"]
                        and not self.shell_state()["menuOpen"]
                    )
                    return [menu, confirmation]

                self.check("shutdown-confirmation", shutdown_confirmation)
            else:

                def keyboard():
                    first = self.app("ghostty")
                    self.app("ghostty")
                    before = self.capture("keyboard-focus-before")
                    self.key(56, 105)  # Alt+Left (Linux evdev KEY_LEFT)
                    if not self.find(first["id"])["is_focused"]:
                        raise RuntimeError("Niri keyboard focus did not move left")
                    after = self.capture("keyboard-focus-after")
                    focused = self.save(
                        "keyboard-focus-transition.json",
                        dict(
                            expectedWindow=first["id"],
                            focusedWindow=self.find(first["id"]),
                            keys=["Alt+Left", "Alt+Q"],
                        ),
                    )
                    self.key(56, 16)  # Alt+Q
                    wait_for(lambda: not self.find(first["id"]))
                    self.clear()
                    return [before, after, focused]

                self.check("keyboard-focus-and-close", keyboard)

                def shutdown_confirmation():
                    command("dms", "ipc", "call", "powermenu", "open")
                    time.sleep(0.5)
                    command("dms", "ipc", "call", "powermenu", "open")
                    time.sleep(0.5)
                    picture = self.capture("shutdown-confirmation")
                    command("dms", "ipc", "call", "powermenu", "close")
                    return [picture]

                self.check("shutdown-confirmation", shutdown_confirmation)
            self.clear()
            outputs = niri("outputs")
            output_name = next(iter(outputs))
            for resolution in self.args.resolutions:
                width, height = map(int, resolution.split("x"))
                command("niri", "msg", "output", output_name, "mode", resolution)
                time.sleep(1)
                logical = niri("outputs")[output_name]["logical"]
                if logical["width"] != width or logical["height"] != height:
                    raise RuntimeError(
                        f"Requested resolution unavailable: {resolution}: {logical}"
                    )
                self.capture(f"desktop-{resolution}")
                if self.args.edition == "win95":
                    self.click(35, height - 16)
                else:
                    command("dms", "ipc", "call", "spotlight", "toggle")
                time.sleep(1)
                self.capture(f"launcher-{resolution}")
                self.key(1)
                if self.args.edition == "tahoe":
                    self.check(
                        f"appearance-switch-{resolution}",
                        lambda: self.appearances(resolution),
                    )
                if resolution == "1280x720":
                    self.current_resolution = resolution
                    self.applications()
                    self.check("shutdown-confirmation", shutdown_confirmation)
                    self.clear()
                    self.current_resolution = ""
            self.save("resolutions.json", self.args.resolutions)
        finally:
            if self.input_available:
                try:
                    self.input_action(
                        "keyup k:125",
                        "keyup k:56",
                        "keyup k:29",
                        "buttonup left",
                        "buttonup right",
                    )
                except OSError as error:
                    self.save("input-cleanup-warning.json", dict(reason=str(error)))
                command(
                    "sudo",
                    "systemctl",
                    "stop",
                    "desktop-test-input.service",
                    check=False,
                )
            self.collect()

    def collect(self):
        for name, args in {
            "user-journal.txt": ("journalctl", "--user", "-b", "--no-pager"),
            "system-journal.txt": ("sudo", "journalctl", "-b", "--no-pager"),
            "renderer.txt": ("eglinfo", "-B"),
            "wayland.txt": ("wayland-info",),
            "boot.txt": ("systemd-analyze",),
        }.items():
            try:
                (self.directory / name).write_text(command(*args, check=False))
            except Exception as error:
                (self.directory / name).write_text(str(error))
        if os.environ.get("NIRI_SOCKET"):
            self.save("windows.json", niri("windows"))
            self.save("outputs.json", niri("outputs"))
            self.save("workspaces.json", niri("workspaces"))

    def metrics(self):
        command("systemctl", "--user", "stop", "desktop-readiness.service")
        self.save(
            "measurement-setup.json",
            dict(
                readinessService=command(
                    "systemctl",
                    "--user",
                    "show",
                    "desktop-readiness.service",
                    "--property=ActiveState",
                    "--property=SubState",
                ).strip(),
                reason="Readiness confirmed before the idle settling interval",
            ),
        )
        self.clear()
        time.sleep(self.args.settle)
        before = cpu_ticks(pathlib.Path("/proc/stat").read_text())
        memory = []
        process_snapshots = []
        deadline = time.monotonic() + self.args.sample
        next_process_sample = time.monotonic()
        while time.monotonic() < deadline:
            memory.append(used_memory(pathlib.Path("/proc/meminfo").read_text()))
            if time.monotonic() >= next_process_sample:
                process_snapshots.append(
                    {
                        "elapsedSeconds": self.args.sample
                        - max(0, deadline - time.monotonic()),
                        "top": process_memory()[:20],
                    }
                )
                next_process_sample += 10
            time.sleep(min(1, max(0, deadline - time.monotonic())))
        after = cpu_ticks(pathlib.Path("/proc/stat").read_text())
        top_processes = summarize_process_memory(process_snapshots)
        self.save(
            "process-memory.json",
            {
                "unit": "bytes",
                "metric": "VmRSS",
                "sampleIntervalSeconds": 10,
                "note": "RSS includes shared pages, so process totals must not be summed as system RAM.",
                "topProcesses": top_processes,
                "snapshots": process_snapshots,
            },
        )
        ready = pathlib.Path(os.environ["XDG_RUNTIME_DIR"]) / "desktop-ready"
        renderer = command("eglinfo", "-B", check=False)
        # The Wayland block is the renderer used by this desktop, not a different EGL platform.
        wayland = renderer.partition("Wayland platform:")[2].partition("X11 platform:")[
            0
        ]
        hardware = (
            bool(wayland)
            and "llvmpipe" not in wayland.lower()
            and "swrast" not in wayland.lower()
            and ("svga" in wayland.lower() or "vmware" in wayland.lower())
        )
        result = dict(
            ramBytes=sum(memory) / len(memory),
            cpuPercent=cpu_percent(before, after),
            readySeconds=float(ready.read_text()) if ready.exists() else None,
            hardwareRendering=hardware,
            settleSeconds=self.args.settle,
            sampleSeconds=self.args.sample,
            ramSamples=memory,
            cpuTicksBefore=before,
            cpuTicksAfter=after,
            processMemoryEvidence="process-memory.json",
        )
        self.save("metrics.json", result)
        self.collect()
        print(json.dumps(result))


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("mode", choices=("suite", "metrics", "capture", "ida"))
    parser.add_argument("--edition", choices=("tahoe", "win95"), required=True)
    parser.add_argument("--output", required=True)
    parser.add_argument("--settle", type=int, default=60)
    parser.add_argument("--sample", type=int, default=120)
    parser.add_argument("--resolutions", nargs="+", default=["1920x1080", "1280x720"])
    args = parser.parse_args()
    session_environment()
    inspection = Inspection(args)
    if args.mode == "metrics":
        inspection.metrics()
    elif args.mode == "capture":
        inspection.capture("desktop")
        inspection.collect()
    elif args.mode == "ida":
        inspection.check("ida-dependency-closure", inspection.ida_dependencies)
        inspection.check("ida-analysis-roundtrip", inspection.ida_functionality)
        print(json.dumps(dict(edition=args.edition, checks=inspection.checks)))
    else:
        inspection.suite()
        print(json.dumps(dict(edition=args.edition, checks=inspection.checks)))


if __name__ == "__main__":
    main()
