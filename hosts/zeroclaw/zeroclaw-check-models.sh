# shellcheck shell=bash
#
# Weekly catalog-drift check for the free-tier ladder, run by systemd
# (zeroclaw-check-models.timer) — never by the agent itself. Giving the agent
# its own path to invoke `zeroclaw` would hand it the whole CLI, including
# `config set` / `estop resume`: ZeroClaw's risk engine classifies commands
# generically (rm/sudo/curl-class patterns for High, git/npm/mv-class verbs
# for Medium) and has no notion of `zeroclaw`'s own subcommands, so anything
# not on that hardcoded list — including every `zeroclaw` subcommand — is Low
# risk and passes with zero gating. A standalone systemd unit sidesteps that
# entirely: nothing here is agent-invocable.
#
# `zeroclaw models list --check` (no `--model-provider` defaults to every
# configured entry) only warns on a stale model and always exits 0, so this
# wrapper greps its output and turns a drift warning into a failed unit —
# the entire point of running it on a timer. No `--all` flag on this binary
# (0.8.4): it was there originally and silently broke every run since this
# timer was written.
#
# Environment:
#   CONFIG_DIR  the running instance's state dir (holds the rendered config.toml)

set -uo pipefail

out="$(zeroclaw models list --check --config-dir "$CONFIG_DIR" 2>&1)"
status=$?

echo "$out"

if [[ $status -ne 0 ]] || grep -qE '⚠️|❌' <<<"$out"; then
  exit 1
fi
