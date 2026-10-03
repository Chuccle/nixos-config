{ self, ... }:
{
  flake.nixosModules.nemoclaw-hermes =
    {
      config,
      lib,
      pkgs,
      ...
    }:
    let
      inherit (lib.attrsets)
        attrNames
        isAttrs
        mapAttrs
        mapAttrs'
        mapAttrsToList
        nameValuePair
        ;
      inherit (lib.lists) concatLists filter singleton;
      inherit (lib.meta) getExe;
      inherit (lib.modules) mkIf;
      inherit (lib.options) mkEnableOption mkOption;
      inherit (lib.strings) concatStringsSep fileContents toJSON;
      inherit (lib.types)
        attrsOf
        bool
        enum
        listOf
        package
        path
        port
        str
        submodule
        ;

      cfg = config.services.nemoclaw-hermes;

      json = pkgs.formats.json { };
      yaml = pkgs.formats.yaml { };

      # Onboarding key -> the OpenShell provider NemoClaw creates for it
      # (`REMOTE_PROVIDER_CONFIG` in src/lib/onboard/providers.ts).
      routeProviderNames = {
        anthropic = "anthropic-prod";
        openai = "openai-api";
        openrouter = "openrouter-api";
      };

      # Endpoint-bound OpenShell provider profiles. OpenShell's built-in
      # `openai` and `anthropic` types are endpointless, so their placeholders
      # would resolve nowhere without a per-sandbox binding; 0.0.116 has no
      # OpenRouter type at all. JSON so the reconcile script can splice in the
      # `resource_version` an update requires.
      profiles = mapAttrs (
        name: provider:
        json.generate "${provider.type}.json" {
          id = provider.type;
          display_name = "${name} for Hermes";
          description = "${name} API access for the Hermes runtime in NemoClaw";
          category = "inference";
          credentials = singleton {
            name = "api_key";
            description = "${name} API key";
            env_vars = singleton provider.credentialEnv;
            required = true;
            auth_style = provider.authStyle;
            header_name = provider.headerName;
          };
          endpoints = map (endpoint: {
            inherit (endpoint) host port;
            protocol = "rest";
            enforcement = "enforce";
            access = "read-write";
          }) provider.endpoints;
          binaries = cfg.hermesBinaries;
          inference_capable = false;
        }
      ) cfg.providers;

      # Egress for direct vendor calls. Profile endpoints bound the credential;
      # this admits the traffic.
      policyPreset = yaml.generate "nemoclaw-hermes-vendors.yaml" {
        preset = {
          name = "hermes-vendors";
          description = "Direct vendor API access for Hermes";
        };
        network_policies = mapAttrs' (
          name: provider:
          nameValuePair "hermes-${name}" {
            name = "hermes-${name}";
            endpoints = map (endpoint: {
              inherit (endpoint) host port;
              protocol = "rest";
              enforcement = "enforce";
              rules =
                map
                  (method: {
                    allow = {
                      inherit method;
                      path = "/**";
                    };
                  })
                  [
                    "GET"
                    "POST"
                  ];
            }) provider.endpoints;
            binaries = map (binary: { path = binary; }) cfg.hermesBinaries;
          }
        ) cfg.providers;
      };

      # One `config set` per leaf; lists stay whole.
      flatten =
        prefix: attrs:
        concatLists (
          mapAttrsToList (
            key: value:
            if isAttrs value then
              flatten "${prefix}${key}." value
            else
              singleton {
                key = "${prefix}${key}";
                value = toJSON value;
              }
          ) attrs
        );

      manifest = json.generate "nemoclaw-hermes-manifest.json" {
        inherit (cfg) gpu sandboxName;
        route = {
          inherit (cfg.defaultRoute) model;
          provider = routeProviderNames.${cfg.defaultRoute.provider};
        };
        policyFile = policyPreset;
        inherit (cfg) excludeBaseline extraPresets;
        settings = flatten "" cfg.hermesSettings;
        providers = mapAttrsToList (name: provider: {
          inherit name;
          inherit (provider) credentialEnv type;
          profileFile = profiles.${name};
        }) cfg.providers;
      };

      reconcile = pkgs.writeShellApplication {
        name = "nemoclaw-hermes-reconcile";
        runtimeInputs = [
          cfg.package
          config.systemd.package
          pkgs.coreutils
          pkgs.gawk
          pkgs.gnugrep
          pkgs.gnused
          pkgs.jq
          self.packages.${pkgs.stdenv.hostPlatform.system}.openshell
        ];
        text = fileContents ./nemoclaw-hermes/reconcile.sh;
      };

      nemoclawOwned = [
        "custom_providers"
        "model"
        "providers"
      ];
    in
    {
      options.services.nemoclaw-hermes = {
        enable = mkEnableOption "Hermes in an NVIDIA NemoClaw sandbox";

        package = mkOption {
          type = package;
          default = self.packages.${pkgs.stdenv.hostPlatform.system}.nemoclaw;
          defaultText = "self.packages.\${system}.nemoclaw";
          description = "NemoClaw CLI package.";
        };

        user = mkOption {
          type = str;
          default = "nemoclaw";
          description = "User that owns the gateway and sandbox. Joins the docker group.";
        };

        group = mkOption {
          type = str;
          default = "nemoclaw";
          description = "Primary group of `user`.";
        };

        stateDir = mkOption {
          type = path;
          default = "/var/lib/nemoclaw";
          description = "HOME of `user`; NemoClaw keeps its state in `~/.nemoclaw`.";
        };

        sandboxName = mkOption {
          type = str;
          default = "hermes";
          description = "Name of the NemoClaw sandbox.";
        };

        policyTier = mkOption {
          type = enum [
            "restricted"
            "balanced"
            "open"
          ];
          # `balanced` adds npm, PyPI, Hugging Face, Homebrew and Brave
          # presets; Hermes needs none of them for inference or tools.
          default = "restricted";
          description = "NemoClaw base policy tier applied at onboarding.";
        };

        extraPresets = mkOption {
          type = listOf str;
          default = [ ];
          example = [ "personal-open-internet" ];
          description = ''
            Built-in NemoClaw policy presets to add on top of `policyTier`,
            e.g. `personal-open-internet` for open web egress (ports 80/443,
            any binary, any public or private address, L4 only).
          '';
        };

        excludeBaseline = mkOption {
          type = listOf str;
          default = [
            "nous_research"
            "nvidia"
          ];
          description = ''
            Hermes baseline policy entries to remove with
            `nemohermes <sandbox> policy exclude`. The defaults are Nous
            update/metadata lookups (updates come from image rebuilds) and
            NVIDIA's API (unused unless the route is NVIDIA). `pypi` is kept
            for skill dependencies; `managed_inference` cannot be excluded.
          '';
        };

        gpu = mkOption {
          type = bool;
          default = false;
          description = "Pass the host GPU through to the gateway and sandbox.";
        };

        defaultRoute = {
          provider = mkOption {
            type = enum (attrNames routeProviderNames);
            default = "anthropic";
            description = "Onboarding provider behind `inference.local` (`NEMOCLAW_PROVIDER`).";
          };

          model = mkOption {
            type = str;
            description = "Model behind `inference.local` (`NEMOCLAW_MODEL`).";
          };
        };

        providers = mkOption {
          description = ''
            Vendors attached to the sandbox as OpenShell providers. The sandbox
            sees a placeholder in `credentialEnv`; the proxy swaps in the real
            key only at `endpoints`.
          '';
          default = {
            anthropic = {
              credentialEnv = "ANTHROPIC_API_KEY";
              secret = "anthropic_api";
              authStyle = "header";
              headerName = "x-api-key";
              endpoints = singleton { host = "api.anthropic.com"; };
            };

            openai = {
              credentialEnv = "OPENAI_API_KEY";
              secret = "openai_api";
              endpoints = singleton { host = "api.openai.com"; };
            };

            openrouter = {
              credentialEnv = "OPENROUTER_API_KEY";
              secret = "openrouter_api";
              endpoints = singleton { host = "openrouter.ai"; };
            };
          };
          type = attrsOf (
            submodule (
              { name, ... }:
              {
                options = {
                  type = mkOption {
                    type = str;
                    default = "hermes-${name}";
                    description = "OpenShell provider profile id; also the provider name.";
                  };

                  credentialEnv = mkOption {
                    type = str;
                    description = "Env var holding the key, both in the secret file and in the sandbox.";
                  };

                  secret = mkOption {
                    type = str;
                    description = "`age.secrets` entry whose file is a `credentialEnv=...` line.";
                  };

                  authStyle = mkOption {
                    type = enum [
                      "bearer"
                      "header"
                    ];
                    default = "bearer";
                    description = "Credential placement recorded in the profile.";
                  };

                  headerName = mkOption {
                    type = str;
                    default = "authorization";
                    description = "Header that carries the credential.";
                  };

                  endpoints = mkOption {
                    description = "Endpoints the credential binds to and the sandbox may reach.";
                    type = listOf (submodule {
                      options = {
                        host = mkOption {
                          type = str;
                          description = "Vendor API host.";
                        };

                        port = mkOption {
                          type = port;
                          default = 443;
                          description = "Vendor API port.";
                        };
                      };
                    });
                  };
                };
              }
            )
          );
        };

        hermesBinaries = mkOption {
          type = listOf str;
          # `managed_inference` binaries in agents/hermes/policy-additions.yaml.
          default = [
            "/usr/local/bin/hermes"
            "/usr/bin/python3.11"
            "/opt/hermes/.venv/bin/python"
          ];
          description = "Hermes executables inside the sandbox image allowed to use the vendor credentials.";
        };

        hermesSettings = mkOption {
          inherit (yaml) type;
          default = { };
          description = ''
            Hermes `config.yaml` values, applied leaf by leaf with
            `nemohermes <sandbox> config set`. `model`, `providers` and
            `custom_providers` belong to NemoClaw.
          '';
        };
      };

      config = mkIf cfg.enable {
        assertions = singleton {
          assertion = filter (key: cfg.hermesSettings ? ${key}) nemoclawOwned == [ ];
          message = ''
            services.nemoclaw-hermes.hermesSettings must not set
            ${concatStringsSep ", " nemoclawOwned}; NemoClaw owns them.
          '';
        };

        virtualisation.docker.enable = true;

        # docker group membership is root-equivalent; NemoClaw requires it.
        users.users.${cfg.user} = {
          isSystemUser = true;
          inherit (cfg) group;
          home = cfg.stateDir;
          createHome = true;
          extraGroups = singleton "docker";
          # NemoClaw runs the OpenShell gateway as a systemd user service.
          linger = true;
        };

        users.groups.${cfg.group} = { };

        environment.systemPackages = singleton cfg.package;

        systemd.services.nemoclaw-hermes = {
          description = "Reconcile the NemoClaw Hermes sandbox";

          wantedBy = singleton "multi-user.target";
          after = [
            "docker.service"
            "network-online.target"
          ];
          wants = [
            "docker.service"
            "network-online.target"
          ];

          environment = {
            HOME = cfg.stateDir;
            NEMOCLAW_AGENT = "hermes";
            NEMOCLAW_NON_INTERACTIVE = "1";
            NEMOCLAW_ACCEPT_THIRD_PARTY_SOFTWARE = "1";
            NEMOCLAW_SANDBOX_NAME = cfg.sandboxName;
            NEMOCLAW_PROVIDER = cfg.defaultRoute.provider;
            NEMOCLAW_MODEL = cfg.defaultRoute.model;
            NEMOCLAW_POLICY_TIER = cfg.policyTier;
            NEMOCLAW_HERMES_MANIFEST = manifest;
          };

          serviceConfig = {
            Type = "oneshot";
            RemainAfterExit = true;
            User = cfg.user;
            Group = cfg.group;
            EnvironmentFile = mapAttrsToList (
              _: provider: config.age.secrets.${provider.secret}.path
            ) cfg.providers;
            ExecStart = getExe reconcile;

            # Only what the docker client, the CLI and its state need. The
            # gateway runs under the user manager, outside this unit. No
            # PrivateTmp: build contexts and TLS bundles staged in /tmp are
            # read by dockerd, which must see the real /tmp. No
            # MemoryDenyWriteExecute: Node's JIT needs W+X pages.
            UMask = "0077";
            NoNewPrivileges = true;
            CapabilityBoundingSet = "";
            ProtectSystem = "strict";
            ReadWritePaths = [
              cfg.stateDir
              "/tmp"
              "/var/tmp"
              "-/run/user"
            ];
            ProtectHome = true;
            PrivateDevices = !cfg.gpu;
            ProtectKernelTunables = true;
            ProtectKernelModules = true;
            ProtectKernelLogs = true;
            ProtectControlGroups = true;
            ProtectClock = true;
            ProtectHostname = true;
            LockPersonality = true;
            RestrictRealtime = true;
            RestrictSUIDSGID = true;
            RestrictAddressFamilies = [
              "AF_UNIX"
              "AF_INET"
              "AF_INET6"
              "AF_NETLINK"
            ];
            SystemCallArchitectures = "native";
          };
        };
      };
    };
}
