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
# `zeroclaw models list --check --all` classifies a stale primary model as a
# *warning*, not a failure, and always exits 0 when checking `--all` — it
# only bails on a verify failure for a single `--model-provider` target with
# zero models verified. So this wrapper reads the check's own output back and
# turns a drifted model into an actual failed systemd unit, which is the
# entire point of running it on a timer instead of by hand.
#
# Environment:
#   CONFIG_DIR  the running instance's state dir (holds the rendered config.toml)

set -uo pipefail

out="$(zeroclaw models list --check --all --config-dir "$CONFIG_DIR" 2>&1)"
status=$?

echo "$out"

if [[ $status -ne 0 ]] || grep -qE '⚠️|❌' <<<"$out"; then
  exit 1
fi
