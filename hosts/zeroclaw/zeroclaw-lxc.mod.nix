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
  ladder = [
    {
      family = "groq";
      models = [
        "llama-3.3-70b-versatile"
        "llama-3.1-8b-instant"
      ];
    }
    {
      family = "cerebras";
      models = [
        "llama-3.3-70b"
        "llama3.1-8b"
      ];
    }
    {
      family = "gemini";
      models = [
        "gemini-2.5-flash"
        "gemini-2.5-flash-lite"
      ];
    }
    {
      family = "openrouter";
      models = [
        "deepseek/deepseek-chat-v3-0324:free"
        "meta-llama/llama-3.3-70b-instruct:free"
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
    { pkgs, ... }:
    let
      # The ladder crosses into the provisioning script as data, not as
      # generated shell — one JSON file the script iterates with jq.
      providersJson = pkgs.writers.writeJSON "zeroclaw-providers.json" (
        map (entry: {
          inherit (entry) family;
          envVar = envVarOf entry;
        }) ladder
      );
    in
    {
      shell.default = "bash";

      environment.systemPackages = [
        pkgs.git
        inputs.llm-agents.packages.${pkgs.stdenv.hostPlatform.system}.zeroclaw

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
        package = inputs.llm-agents.packages.${pkgs.stdenv.hostPlatform.system}.zeroclaw;

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

          # Loopback only and pairing required. The box is reached over
          # WireGuard, so nothing here is published to the network — note
          # there is deliberately no firewall hole for it below.
          gateway = {
            host = "127.0.0.1";
            require_pairing = true;
            allow_public_bind = false;
          };
        };
      };

      # Upstream leaves resource caps to the caller on purpose (a Rust agent's
      # profile is entirely workload-dependent), so they are set here.
      systemd.services."zeroclaw-${instanceName}" = {
        after = singleton "secrets-bootstrap.service";

        serviceConfig = {
          MemoryMax = "1536M";
          MemoryHigh = "1280M";
          CPUQuota = "150%";
          TasksMax = 512;
        };
      };

      services.openssh.enable = false;
      services.getty.autologinUser = "root";

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
