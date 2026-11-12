# AGENTS.md

A dendritic NixOS flake: `flake.nix` imports every `*.mod.nix` below the root.
The aim is orthodox dendritic Nix — one small module per subject, no duplicated
values inside a module, no dead code, no ceremony.

## Before you finish

```bash
nix flake check   # formatting, deadnix, statix, actionlint
nix fmt           # expect "0 changed"
```

## One file, one subject

- Every `*.mod.nix` is a flake-parts module. Do not list modules in `flake.nix`;
  creating the file is the registration.
- A file owns one subject. It may expose that subject for several classes
  (`nixosModules.foo`, `homeModules.foo`, `perSystem.packages.foo`); unrelated
  subjects get their own file. Multiple outputs of one class are allowed only
  when they are two halves of one subject (`helix` and `helix-desktop`).
- This is a rule for `modules/`; a host is a composition root and may carry its
  own base configuration, including settings another host also uses. Repeating a
  host's base is fine; do not add a profile module just to remove it.
- A live image may extend the host it images (`blorg-live` extends `blorg`).
- Name the file after the subject: `modules/version-control/jujutsu.mod.nix`
  owns `homeModules.jujutsu`; `modules/desktop/ghostty.mod.nix` owns
  `homeModules.desktop-ghostty`. A service stack is a module in its own
  directory with its files (`modules/ente-server/ente-server.mod.nix`,
  `secrets.nix`, and its shell scripts); the host only sets its options.
- Hosts compose modules. A host is an imports list plus the configuration that
  belongs to that machine: hostname (except where the platform manages it, e.g.
  Proxmox LXC), filesystems, users, `stateVersion`, addresses, display outputs.
  It supplies values, not implementations. A service implementation — systemd
  units, its users, firewall, secrets — lives in a module with options; the host
  sets the options. Enabling a standard NixOS service is configuration and may
  stay in the host.
- Modules are pure. A module knows no hostname, address, or host-specific path,
  never branches on which host is evaluating it, and never imports a host.
  Anything a host must choose is an option; the host sets it. A home module may
  read `osConfig` for the NixOS side of its own subject (niri's final config,
  display outputs); it must not hardcode host identity.
- Options that are not flake outputs live with the module that owns them.
  `options/` is for cross-module infrastructure only.

## Home configuration

- Home configuration is hjem with hjem-rum. There is no Home Manager in this
  flake.
- `flake.homeModules.<name>` is a hjem module; hosts import it under
  `home.users.<name>.imports`. `flake.nixosModules.<name>` is a NixOS module.
- hjem-rum exposes `rum.programs.*`; `flake.homeModules.home` aliases
  `programs` to it, so import that module before using `programs.*`. Where
  hjem-rum has no module (Haruna, Dolphin, Qt), write the program file under
  `xdg.config`.

## Module shape

- `{ ... }: { ... }`, or a plain attrset when no arguments are needed.
  Destructure only what you use, alphabetically, ending in `...`.
- A module without `options` writes settings at the top level. A module with
  `options` puts them under `config`; the module system requires it. Read
  options through `config.foo`; a `let` alias is fine when the value is read
  more than once (`cfg`, `garage`, `s3`), never a single-use copy.

## Whitespace and order

- `nix fmt` owns indentation, wrapping, and alignment. Never hand-align.
- Module keys read `imports`, `options`, then `config` (or the settings
  themselves); `key` may come first. `let` precedes the body.
- Config order is by concern, not alphabetically: environment, packages, XDG,
  program config; then the subject's enable/identity before the settings that
  depend on it. Group an XDG entry with the environment variable that points at
  it.
- One blank line between unrelated groups; none inside a group or immediately
  inside `{`, `[`, or `(`. `nix fmt` does not check this.
- In a `let`, order by dependency. A binding sits above its first use.
- An option reads `type`, `default`/`defaultText`/`apply`, then
  `description`/`example`; a long `type` may sit last.
- Alphabetise top-level module arguments, names inside one `inherit`, and lib
  paths across `inherit` lines. Do not reorder or insert before an existing
  package or import list unless the evaluated value is unchanged: list order can
  be semantic.
- Section comments are uppercase and unpunctuated, above the group they
  explain. No comment restates the code.

## Minimal code

- The smallest module that states the configuration wins. Do not add a wrapper
  or a binding that only renames a call.
- `let` is for a value used more than once, a helper used more than once, or a
  `getExe` shortcut. Never `let tmp = …; in f tmp`.
- A helper usually earns its name from a second call site. A one-use helper
  must explain something — a format, a derived path, a long literal — not just
  rename a call.
- `inherit (lib.<path>)` with full paths and alphabetised names. Never
  `inherit (lib)` when a submodule path exists, never `builtins.`, never `rec`.
- `singleton` for one item; `optional`/`optionals` for conditional lists;
  `optionalString` for conditional strings.
- Use `|>` when the value is the subject of the steps. A single step is fine
  when it reads better than a nested call; do not wrap a call with nothing
  flowing through it. `<|` is not a pipeline: it replaces parentheses around a
  final argument. Do not use it to chain, for a bare term, where a following
  `//` captures it, or where nixfmt strands it.
- `mkIf` on the option, not around a whole attrset, unless every option in the
  block shares the condition.
- Inline packages with `pkgs.callPackage ({ ... }: ...) { }`. A package's
  `perSystem` lives in its own `.mod.nix`, separate from the module that
  consumes it. `writeText` directly in `src`.
- A truthful `/* lang */` before every multiline code string: `/* jj */` for jj
  revsets and templates, `/* bash */` for shell, `/* python */` for Python.

## Purity

- A module configures its subject and nothing else. No unrelated options, no
  cross-host conditionals, no feature flags for one host.
- Do not duplicate a value a module option owns inside one module. Two hosts may
  set the same option; host-local repetition is fine. Aliases such as
  `cfg = config.secrets` are not duplication.
- New outputs, options, and bindings need a consumer. If you find one without
  a consumer, wire it or delete it; if it is public API, say so in a comment.
- Prefer deleting an abstraction to keeping a bad one. A helper used by a second
  module belongs in a shared module; a helper used only within one module may
  stay.

## Scripts

- `pkgs.writeShellApplication` with `runtimeInputs`; no raw store paths
  (except `secrets.files.*.script`, which has no runtime-inputs option yet).
- Standalone scripts: `# shellcheck shell=bash`, `set -euo pipefail`, quoted
  expansions, fail loudly.

## CI

- `checks` are lints. `nix flake check` builds them and evaluates every host; it
  does not build a system.
- Build jobs name `nixosConfigurations.<host>.config.system.build.toplevel`
  and, where the host has one, its package — in the same selection, or in an
  explicit step gated on that artifact's condition (e.g. `publish-iso` for the
  ISO). Never resurrect `checks.host-*`.
- Only `main` publishes to Cachix.

## Litmus tests

- Can you name the file's subject in one word?
- Does every `let` binding have a second use or a name worth reading?
- Is any write in a module without `options` still using `config.`?
- Can the file be read top-to-bottom without jumping?
- Delete a binding, option, or output with no consumer. A list entry is not
  free to delete: order and duplicates can change the evaluated value even when
  the closure is identical.
- Does the module know a hostname, address, or host-specific path? That value
  belongs in the host, behind an option.
