# Live ISO desktop workflow

Run from PowerShell 7.4 or newer in the repository:

```powershell
./workflow/desktop-workflow.ps1 -Mode improve -Edition both
```

The single `improve` invocation performs preflight, builds or reuses baseline ISOs,
three fresh baseline boots per edition, current builds, three fresh verification
boots per edition, and bounded repairs. Build activity is stopped before each VM
benchmark. It writes a run directory under `C:\Projects\nixos-desktop-runs` with
`report.html`, `run.json`, frozen criteria, source hashes, SHA-256 ISO checksums,
VM configurations, screenshots, journals, renderer output, and functional JSON.
Idle measurements also record the 20 largest processes by resident memory every
10 seconds; the report shows their average and peak use for each fresh boot.
Resident values include shared pages and therefore do not sum to system RAM.
Each candidate is retained with its own source snapshot and evidence. A pass is
reported only when every required check has evidence.

Use `-ReuseRunId <prior-run>` with `improve` to reuse checksummed baseline ISOs
while collecting fresh baseline measurements. Candidates are built from the
current source; earlier verification results are not copied into the new run.

For staged work, use `-Mode preflight`, then `-Mode build`, then `-Mode verify`.
Supply the same `-RunId` on subsequent invocations. `-Edition` can be `both`,
`tahoe`, or `win95`. `-Baseline` on `build` or `verify` selects the original
desktop source snapshot. Configurable paths and limits are in `config.json`;
acceptance criteria are in `criteria.json`. Both files are frozen per run.
If a six-hour run ends after building valid ISOs, start a new bounded run with
`-Mode adopt -ReuseRunId <old-run-id> -RunId <new-run-id>`. This verifies the
old ISO and source-manifest hashes, hard-links the images without duplicating
their disk use, and requires fresh verification boots in the new run.

The workflow needs Docker Desktop with `C:\Projects` shared, VMware Workstation,
an authenticated Codex CLI, SSH tools, and the pinned `jj` executable in the
configured tools location. It builds the devcontainer image when needed and
creates or reuses the explicitly named persistent Nix volume. It generates an
Ed25519 inspection key under the artifact directory. Only its public key enters
live ISOs. The private key and VM host keys stay outside source and ISO artifacts.
Preflight raises Docker Desktop's documented Resource Saver idle timeout beyond
the run budget if needed, backing up the original settings beside Docker's
settings file. This avoids native-VM shutdown during the multi-boot benchmarks.
If Docker is unavailable, preflight recognizes the specific Secrets Engine
orphaned AF_UNIX socket failure described in
[Docker for Windows issue 15064](https://github.com/docker/for-win/issues/15064).
`repair-docker-secrets.ps1` stops Docker, verifies the socket directory's contents,
and preserves that directory under a new name before restarting the engine.
It leaves healthy engines alone and records the result. This recovery does not
apply to the separate `vm-data` vsock listener error: that directory contains
the disk image and must remain intact. Verification of already built ISOs can
continue without Docker through `adopt` and `verify`.

Nix commands use `/nix/store` from the persistent volume with an isolated
workflow state database at the configured `nixStateDir`. This keeps a damaged
pre-existing database untouched. Source snapshots normalize Nix files to LF
before hashing because Nix preserves CRLF inside multiline shell builders.
The baseline is materialized from the configured immutable `baselineRevision`
with `jj`; the current desktop comes from `candidateRoot`. The controller
records each source commit and file hash with the resulting ISO.
Each verification boot also records hashes of the controller's inspection
scripts copied into the guest. Inspection fixes can therefore be applied to
an existing ISO without losing the provenance of the code collecting evidence.
The inspection build enters through `inspection-build.nix`; VMware options and
the public key are checked as Nix module options in the guest profile.
For an unchanged labwc Win95 baseline in VMware, the controller can relaunch
its Quickshell panel with Qt Quick's software scene graph if the original panel
exits on a DMA-BUF import error. It records this baseline-only intervention in
each boot's evidence. The readiness probe requires the compositor's Wayland
socket and a reply from the active Quickshell configuration's IPC. The controller
runs this same probe for baseline and candidate boots, retaining its hash and
result even when a readiness marker already exists. Candidate editions remain subject to the hardware renderer
and idle limits.

The run freezes visual references, including Apple's Golden Gate desktop and
Liquid Glass imagery and original Windows 95 desktop screenshots. Each visual
review receives the references and guest screenshots, then writes
criterion-level findings with source IDs and evidence filenames. The guest
activates Ghostty, Dolphin, Ark, Helium and IDA through the shell's keyboard launcher,
recording each result even when an earlier application fails. It also repeats
application launches, file and archive dialogs, and shutdown confirmation
at 1280×720, retaining separate screenshots from the initial desktop inspection.
Tahoe additionally switches DMS between light and dark appearances at both
resolutions, records the mode reported by its IPC, and captures the desktop,
launcher and Ghostty before restoring the original mode. `Super+Shift+T` toggles
the shell appearance interactively. Ghostty follows the shell's saved mode;
applications with a fixed Qt palette may need a separate appearance build.
User-supplied supplemental references do not replace a run's frozen criteria
or reference manifest.
Dotool supplies keyboard input and absolute pointer coordinates through a Nix
configured service. Its pipe is writable by the live user's group. The service
runs only during functional checks and stops before idle measurements.
The inspection profile also runs `ldd` across IDA's installed ELF files and
captures `strace -f -e trace=openat` during an IDA launch. On every candidate
boot the controller accepts IDA 9.4's EULA in that ephemeral guest home using
the same idalib registry API as Hex-Rays HCLI's `--accept-eula`. It records the
helper hash and result beside the boot evidence; no acceptance state is baked
into an ISO. It then analyzes an ELF fixture with IDAPython, requires discovered
functions and disassembly, saves an `.i64` database, reopens it, and checks
that the analysis and a function rename survived. If Hex-Rays is available, it
also requires generated pseudocode. The fixture, IDA logs, JSON results, and database
hash are retained as evidence.

Win95 uses the maintained niri IPC event stream for taskbar updates. A small
shell adapter stores window IDs, original workspaces, floating geometry and
focus state under the session runtime directory, and moves hidden windows to
the named `parked` workspace without following them. That workspace remains
visible in niri's overview. Use a taskbar button or `Alt+M` to hide a window,
the taskbar to restore it, `Super+left-drag` to move, and `Super+right-drag` to
resize. `Alt+Tab` switches focus and `Alt+F4` closes. Application titlebars are
used where provided; an application's own minimize button cannot call this
taskbar mechanism.
