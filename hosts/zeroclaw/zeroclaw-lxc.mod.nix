{
  inputs,
  lib,
  self,
  ...
}:
let
  inherit (lib.attrsets) listToAttrs nameValuePair;
  inherit (lib.lists) drop head singleton;
  inherit (lib.strings) fileContents;

  # The systemd unit upstream generates is `zeroclaw-<instance>.service`.
  instanceName = "assistant";

  secretsDir = "/var/lib/secrets/zeroclaw";
  providerEnvFile = "${secretsDir}/providers.env";

  # FREE-TIER LADDER
  # Ordered best-first. The head alias is what the agent points at; every
  # other alias lands in the head's `fallback` list in this order, so a
  # rate-limited or dead vendor walks the whole ladder inside one turn before
  # the request is allowed to fail.
  #
  # Kept flat rather than chained (a -> b -> c) on purpose: ZeroClaw prunes
  # fallback chains past MAX_FALLBACK_DEPTH = 3 *recursion levels*, and a flat
  # list hanging off one alias is depth 1 for every link — so the ladder can
  # grow past three vendors without silently losing its tail.
  #
  # `models` is best-first within a vendor: `fallback_models` is walked before
  # leaving the alias, on the same endpoint and key, so a per-model quota
  # drops to the vendor's smaller model rather than costing a whole hop.
  #
  # Model IDs are vendor-side names and they drift. Nothing validates them at
  # config load — a stale ID is only discovered when the vendor rejects the
  # request, at which point the ladder falls through to the next model and then
  # the next vendor, so a wrong entry degrades quietly rather than breaking the
  # agent. `zeroclaw models refresh --model-provider <family>.free` lists what
  # an endpoint actually advertises today.
  # Verified against each vendor's live catalog on 2026-09-03 (Cerebras'
  # public docs table, Groq's rate-limits table, and a keyless fetch of
  # OpenRouter's /models endpoint — the `zeroclaw-check-models` systemd timer
  # below is the repeatable version of that check, since these numbers don't
  # hold forever). Two rungs had gone quietly dead since this ladder was first
  # written: Cerebras
  # dropped the whole Llama family from its public
  # endpoints in favor of gpt-oss-120b/gemma-4-31b, and both OpenRouter
  # `:free` IDs had rotated out of the catalog entirely. Groq's head model also
  # moves to gpt-oss-120b here: same 1K req/day as llama-3.3-70b-versatile but
  # double the token budget (200K vs ~100K TPD) on a comparable-or-stronger
  # model. Gemini moved 2026-09-05: gemini-2.5-flash/-lite now 404 for this
  # key ("no longer available to new users"), confirmed live against the AI
  # Studio key — gemini-3.6-flash/gemini-3.5-flash-lite (no 3.6 lite exists
  # yet) both verified working. Both Llama fallbacks went the same day: Groq
  # dropped the whole Llama lineup from this key too (empty of any Llama
  # model on a live /v1/models fetch), same as it once dropped Cerebras' —
  # replaced with gpt-oss-20b, the smaller sibling of the head model, since
  # nothing else on this key's catalog fits the fallback's job. OpenCode Zen
  # added 2026-09-05. Its keyless /models listing includes many
  # `-free`-suffixed IDs, but most aren't real: an authenticated key sees a
  # different, unsuffixed catalog, and posting the keyless names to
  # /chat/completions 401s regardless of auth. Confirmed working set is
  # smaller and vendor-documented, not name-pattern-derived.
  ladder = [
    {
      family = "groq";
      models = [
        "openai/gpt-oss-120b"
        "openai/gpt-oss-20b"
      ];
    }
    {
      family = "cerebras";
      models = [
        "gpt-oss-120b"
        "gemma-4-31b"
      ];
    }
    {
      family = "gemini";
      models = [
        "gemini-3.6-flash"
        "gemini-3.5-flash-lite"
      ];
    }
    {
      family = "openrouter";
      models = [
        "z-ai/glm-5.2:free"
        "nvidia/nemotron-3-super-120b-a12b:free"
      ];
    }
    {
      family = "opencode";
      models = [
        "big-pickle"
        "mimo-v2.5-free"
        "ling-3.0-flash-fin-free"
        "nemotron-3-ultra-free"
        "nemotron-3.5-lightning-free"
      ];
    }
  ];

  # `<family>.free` — one alias per vendor, all named `free` so the dotted
  # reference reads as what it is.
  aliasOf = { family, ... }: "${family}.free";

  mkProvider =
    extra:
    { family, models }:
    nameValuePair family {
      free = {
        model = head models;
        fallback_models = drop 1 models;
        timeout_secs = 120;
      }
      // extra;
    };

  providerModels = listToAttrs (
    # Only the head alias carries the ladder; the rest are plain leaves.
    singleton (mkProvider { fallback = map aliasOf (drop 1 ladder); } (head ladder))
    ++ map (mkProvider { }) (drop 1 ladder)
  );

  # ZeroClaw resolves `ZEROCLAW_providers__models__<family>__<alias>__api_key`
  # from the environment at load time, so no key ever appears in `settings` —
  # not even as an envsubst placeholder in the world-readable store copy.
  envVarOf = { family, ... }: "ZEROCLAW_providers__models__${family}__free__api_key";

  modules = [
    "${inputs.nixpkgs}/nixos/modules/virtualisation/proxmox-lxc.nix"
    "${inputs.zeroclaw}/nix/module.nix"
    self.nixosModules.security
    self.nixosModules.shell
    self.nixosModules.nix
    self.nixosModules.nuke-default-packages
    self.nixosModules.secrets
    self.nixosModules.zeroclaw-assertions
  ]
  ++ singleton (
    {
      pkgs,
      lib,
      config,
      ...
    }:
    let
      # WEB DASHBOARD
      # `embedded-web` bakes `web/dist` into the binary via `include_dir!`.
      # It is not part of the crate's `default` feature set, and the packaged
      # build runs `npm run build` but installs only the cargo binaries — so
      # without this the dashboard is compiled and then thrown away, and the
      # gateway answers every non-API route with its 503 "Web dashboard not
      # available" page. Upstream's other option is serving the directory
      # from disk via `gateway.web_dist_dir`, but that needs the same rebuild
      # just to get `web/dist` into the store, so embedding is the shorter
      # path to the same result.
      #
      # `cargoBuildFeatures` is the attribute `cargoBuildHook` actually
      # reads. `buildFeatures` is an argument to `buildRustPackage` itself
      # and is already consumed by the time `overrideAttrs` runs, so setting
      # that name here would be accepted and then ignored.
      #
      # This does cost the numtide binary cache — the override changes the
      # derivation, so the Rust workspace is built from source.
      zeroclaw =
        let
          upstream = inputs.llm-agents.packages.${pkgs.stdenv.hostPlatform.system}.zeroclaw;
        in
        upstream.overrideAttrs (old: {
          cargoBuildFeatures = (old.cargoBuildFeatures or [ ]) ++ singleton "embedded-web";
        });

      # The ladder crosses into the provisioning script as data, not as
      # generated shell — one JSON file the script iterates with jq.
      providersJson = pkgs.writers.writeJSON "zeroclaw-providers.json" (
        map (entry: {
          inherit (entry) family;
          envVar = envVarOf entry;
        }) ladder
      );

      instanceCfg = config.services.zeroclaw.instances.${instanceName};

      checkModelsScript = pkgs.writeShellApplication {
        name = "zeroclaw-check-models";
        runtimeInputs = [
          pkgs.coreutils
          pkgs.gnugrep
          zeroclaw
        ];
        runtimeEnv = {
          CONFIG_DIR = instanceCfg.dataDir;
        };

        text = fileContents ./zeroclaw-check-models.sh;
      };
    in
    {
      shell.default = "bash";

      environment.systemPackages = [
        pkgs.git
        zeroclaw

        # PROVISIONING
        # Interactive, operator-run, never touched at boot. The ladder reaches
        # it as generated JSON rather than generated shell, so adding a vendor
        # above needs no change to the script — and shellcheck runs over the
        # script itself at build time.
        (pkgs.writeShellApplication {
          name = "zeroclaw-keys";
          runtimeInputs = [
            pkgs.coreutils
            pkgs.jq
            pkgs.systemd
          ];
          runtimeEnv = {
            PROVIDERS = providersJson;
            ENV_FILE = providerEnvFile;
            UNIT = "zeroclaw-${instanceName}.service";
          };

          text = fileContents ./zeroclaw-keys.sh;
        })

        checkModelsScript
      ];

      # Content comes from `zeroclaw-keys`; the module owns the directory and
      # the mode so the file is never left group-readable after a hand edit.
      secrets.files."zeroclaw/providers.env".path = providerEnvFile;

      # ZEROCLAW
      # Upstream's own multi-instance module (nix/module.nix, pinned to the tag
      # the binary is built from). It renders `settings` to config.toml in the
      # state directory, loads the env file, and applies a hardening profile
      # modelled on services.atticd — so none of that is reimplemented here.
      services.zeroclaw.instances.${instanceName} = {
        package = zeroclaw;

        # The unit carries ConditionPathExists on this, so before the operator
        # has run `zeroclaw-keys` the agent stays cleanly inactive instead of
        # crash-looping against a vendor it has no credential for.
        environmentFile = providerEnvFile;

        settings = {
          providers.models = providerModels;

          # SUPERVISED, WORKSPACE-SCOPED
          # `level` is the autonomy dial: supervised acts on its own but stops
          # for approval on anything the risk engine grades risky. Everything
          # here is an allow-list — there is no `forbidden_commands` field in
          # the schema, so denial is expressed by what is left out of
          # `allowed_commands`, not by a blocklist that would be silently
          # dropped at load.
          risk_profiles.assistant = {
            level = "supervised";
            workspace_only = true;
            block_high_risk_commands = true;
            require_approval_for_medium_risk = true;

            allowed_commands = [
              "curl"
              "git"
              "ip"
              "journalctl"
              "nix"
              "ping"
              "systemctl"
            ];

            forbidden_paths = [
              "/boot"
              "/etc"
              "/sys"
              "/var/lib/secrets"
              "~/.ssh"
            ];
          };

          agents.assistant = {
            model_provider = aliasOf (head ladder);
            risk_profile = "assistant";
            cron_jobs = singleton "tidy-memory";

            # Deliberately empty. `agents.*.channels` entries must be dotted
            # `<type>.<alias>` refs resolving into a channel *map*, and
            # `[channels] cli` is a plain bool, not a map — so naming it here
            # (as `"cli"` or `"cli.main"`) is a dangling reference that fails
            # Config::validate() at startup rather than enabling anything.
            # The CLI is switched on by `channels.cli = true` below; an agent
            # with no bound channel is the valid shape for one driven by the
            # heartbeat, cron, and operator-initiated turns.
            channels = [ ];
          };

          # AUTONOMY
          # What makes this an agent that keeps running rather than a REPL:
          # the heartbeat wakes it on its own schedule, and cron gives it
          # standing work. `adaptive` lets it stretch the interval out when
          # nothing is happening, which on a free tier is the difference
          # between a day of quota and an hour of it.
          heartbeat = {
            enabled = true;
            agent = "assistant";
            adaptive = true;
            interval_minutes = 30;
            min_interval_minutes = 15;
            max_interval_minutes = 240;
          };

          cron.tidy-memory = {
            job_type = "agent";
            schedule = {
              kind = "cron";
              expr = "0 4 * * *";
            };
            enabled = true;
            uses_memory = true;
            prompt = ''
              Review what you learned today, consolidate it into long-term
              memory, and drop anything that turned out to be noise.
            '';
          };

          # Keyword-only recall: no embedding provider means no embedding API
          # spend, which matters when the whole point is free inference.
          memory = {
            backend = "sqlite";
            embedding_provider = "none";
            auto_save = true;
            hygiene_enabled = true;
          };

          channels.cli = true;

          # Bound to all interfaces so the web dashboard / gateway API (the
          # Tauri app and zerocode TUI pair against the same endpoint) is
          # reachable from the LAN — WAN never reaches this LXC directly,
          # only via the OPNsense VM router's WireGuard, so this is a LAN
          # boundary, not a public one. `allow_public_bind` just silences
          # ZeroClaw's own "bound to all interfaces" warning; the actual
          # auth boundary is `require_pairing`, unchanged. Port 42617 is
          # upstream's default — opened in the firewall below.
          gateway = {
            host = "0.0.0.0";
            require_pairing = true;
            allow_public_bind = true;
          };
        };
      };

      # Upstream leaves resource caps to the caller on purpose (a Rust agent's
      # profile is entirely workload-dependent), so they are set here.
      systemd.services."zeroclaw-${instanceName}" = {
        after = singleton "secrets-bootstrap.service";

        # Upstream's hardened PATH has no shell package, so the agent's
        # shell tool failed every call with `sh not found on PATH`. Extends
        # rather than replaces the existing PATH.
        path = singleton pkgs.bash;

        serviceConfig = {
          MemoryMax = "1536M";
          MemoryHigh = "1280M";
          CPUQuota = "150%";
          TasksMax = 512;
        };
      };

      # SELF-AUDIT
      # The ladder above is a snapshot: vendor catalogs drift underneath it
      # with no signal when a rung goes dead (checking this by hand while
      # writing it found Cerebras had dropped its whole Llama lineup, and
      # both OpenRouter `:free` IDs had rotated out — neither failure is
      # loud, the request just falls through to the next vendor).
      #
      # This runs as a plain systemd timer, deliberately outside the agent's
      # own cron/tool-call path — see zeroclaw-check-models.sh for why:
      # short version, the risk engine has no notion of `zeroclaw`'s own
      # subcommands, so allowlisting the binary for a read-only check would
      # also allowlist `config set` and `estop resume` with no gating at all.
      # A oneshot unit outside the agent means there is nothing here for the
      # agent to invoke, misuse, or be tricked into invoking.
      systemd.services."zeroclaw-check-models" = {
        description = "ZeroClaw free-tier ladder catalog-drift check";
        after = singleton "zeroclaw-${instanceName}.service";

        # Needs both the secrets (to query each vendor's catalog) and a
        # config.toml already rendered by the main unit's ExecStartPre — on
        # a fresh box neither exists until `zeroclaw-keys` has been run once.
        unitConfig.ConditionPathExists = "${instanceCfg.dataDir}/config.toml";

        serviceConfig = {
          Type = "oneshot";
          User = instanceCfg.user;
          Group = instanceCfg.group;
          EnvironmentFile = providerEnvFile;
          ExecStart = lib.getExe checkModelsScript;

          NoNewPrivileges = true;
          PrivateTmp = true;
          ProtectSystem = "strict";
          ProtectHome = true;
        };
      };

      systemd.timers."zeroclaw-check-models" = {
        description = "Weekly ZeroClaw catalog-drift check";
        wantedBy = singleton "timers.target";
        timerConfig = {
          OnCalendar = "Mon *-*-* 06:00:00";
          Persistent = true;
        };
      };

      services.openssh.enable = false;
      services.getty.autologinUser = "root";

      # Gateway dashboard/API — matches gateway.host = "0.0.0.0" above.
      networking.firewall.allowedTCPPorts = [ 42617 ];

      xdg.sounds.enable = false;
      xdg.mime.enable = false;
      xdg.icons.enable = false;
      fonts.fontconfig.enable = false;

      nixpkgs.hostPlatform = "x86_64-linux";
      system.stateVersion = "25.11";
    }
  );
in
{
  flake.nixosConfigurations.zeroclaw-server-lxc = inputs.nixpkgs.lib.nixosSystem {
    inherit modules;
  };

  flake.packages.x86_64-linux.zeroclaw-server-lxc =
    self.nixosConfigurations.zeroclaw-server-lxc.config.system.build.tarball;
}
