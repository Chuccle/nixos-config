import unittest
import tempfile

import importlib.util
from pathlib import Path
from types import SimpleNamespace
from unittest.mock import patch

spec = importlib.util.spec_from_file_location(
    "guest_inspect", Path(__file__).with_name("guest-inspect.py")
)
guest_inspect = importlib.util.module_from_spec(spec)
spec.loader.exec_module(guest_inspect)

ready_spec = importlib.util.spec_from_file_location(
    "desktop_ready", Path(__file__).with_name("desktop-ready-probe.py")
)
desktop_ready = importlib.util.module_from_spec(ready_spec)
ready_spec.loader.exec_module(desktop_ready)


class ReadinessTests(unittest.TestCase):
    def test_shell_must_reply_using_its_actual_configuration(self):
        with (
            patch.object(
                Path, "read_bytes", return_value=b"quickshell\0-p\0/store/dms\0"
            ),
            patch.object(desktop_ready.subprocess, "run") as ipc,
        ):
            ipc.return_value.returncode = 1
            self.assertFalse(desktop_ready.shell_responds(123))
            ipc.assert_called_once_with(
                ["quickshell", "-p", "/store/dms", "ipc", "show"],
                capture_output=True,
                timeout=3,
                check=False,
            )
            ipc.return_value.returncode = 0
            self.assertTrue(desktop_ready.shell_responds(123))

    def test_unresponsive_shell_is_not_ready(self):
        with (
            patch.object(Path, "read_bytes", return_value=b"quickshell\0-c\0win95\0"),
            patch.object(
                desktop_ready.subprocess,
                "run",
                side_effect=desktop_ready.subprocess.TimeoutExpired("quickshell", 3),
            ),
        ):
            self.assertFalse(desktop_ready.shell_responds(123))


class MeasurementTests(unittest.TestCase):
    def test_normalized_cpu(self):
        before = guest_inspect.cpu_ticks("cpu 10 0 10 980 0 0 0 0 0 0\n")
        after = guest_inspect.cpu_ticks("cpu 20 0 20 1960 0 0 0 0 0 0\n")
        self.assertEqual(guest_inspect.cpu_percent(before, after), 2.0)

    def test_memory_uses_available(self):
        self.assertEqual(
            guest_inspect.used_memory(
                "MemTotal: 4000 kB\nMemFree: 1000 kB\nMemAvailable: 3000 kB\n"
            ),
            1024000,
        )

    def test_guest_ticks_not_counted_twice(self):
        self.assertEqual(
            guest_inspect.cpu_ticks("cpu 20 0 0 80 0 0 0 0 10 0"), (100, 80)
        )

    def test_idle_process_breakdown(self):
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            for pid, name, rss in ((10, "niri", 100), (20, "quickshell", 200)):
                directory = root / str(pid)
                directory.mkdir()
                (directory / "status").write_text(f"Name:\t{name}\nVmRSS:\t{rss} kB\n")
            processes = guest_inspect.process_memory(root)
            self.assertEqual(
                [item["name"] for item in processes], ["quickshell", "niri"]
            )
            self.assertEqual(processes[0]["rssBytes"], 200 * 1024)
            snapshots = [
                {"top": processes},
                {"top": [{**processes[0], "rssBytes": 300 * 1024}]},
            ]
            summary = guest_inspect.summarize_process_memory(snapshots)
            self.assertEqual(summary[0]["averageRssBytes"], 250 * 1024)
            self.assertEqual(summary[0]["peakRssBytes"], 300 * 1024)
            self.assertEqual(summary[0]["samples"], 2)


class LauncherTests(unittest.TestCase):
    def test_failed_activation_keeps_later_application_evidence(self):
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            desktop = root / "applications.desktop"
            desktop.write_text("Ghostty Dolphin Ark Helium IDA")
            inspection = guest_inspect.Inspection(
                SimpleNamespace(output=str(root), edition="tahoe")
            )

            def activate(query):
                if query == "Ghostty":
                    raise RuntimeError("No window appeared")
                return [f"launcher-activation-{query.lower()}.png"]

            with (
                patch.object(guest_inspect.glob, "glob", return_value=[str(desktop)]),
                patch.object(
                    inspection, "activate_launcher", side_effect=activate
                ) as launch,
                patch.object(inspection, "capture", return_value="failed-ghostty.png"),
                patch.object(inspection, "clear"),
                patch.object(inspection, "key"),
            ):
                with self.assertRaisesRegex(RuntimeError, "Launcher activation failed"):
                    inspection.launchers()
            self.assertEqual(
                [call.args[0] for call in launch.call_args_list],
                ["Ghostty", "Dolphin", "Ark", "Helium", "IDA"],
            )
            results = guest_inspect.json.loads(
                (root / "launcher-results.json").read_text()
            )
            self.assertEqual(
                [result["status"] for result in results],
                ["fail", "pass", "pass", "pass", "pass"],
            )


if __name__ == "__main__":
    unittest.main()
