# Hermes Agent — the web dashboard, and the seam that lets a NixOS host own
# part of its configuration.
#
# Hermes reads `~/.hermes/config.yaml`, which the operator and the dashboard
# both write. A host that wants to own the routing and the autonomy dials
# cannot simply overwrite that file without taking away every preference the
# operator has set. Upstream provides the split: a *managed scope*
# (`hermes_cli/managed_scope.py`) deep-merges a root-owned
# `/etc/hermes/config.yaml` on top of the user's, per leaf key. A key declared
# here is pinned; a key left out stays operator-writable.
#
# `settings` is a plain attrset rendered by `pkgs.formats.yaml`. That format's
# type is the type checking: it rejects anything YAML cannot carry, and it
# tracks Hermes' ~900-key surface for free by not pretending to enumerate it.
# The alternative — restating the key tree as module options — buys an
# unknown-key error in exchange for a schema that goes stale the first time
# upstream renames something, which is the failure it was supposed to prevent.
# What a type genuinely cannot check — upstream behaviour, like refusing a
# non-loopback bind with no auth provider — lives in the assertions below.
#
# The service also sets `HERMES_MANAGED=nixos`, Hermes' separate
# package-manager write lock. It blocks `hermes update`, the setup wizard and
# gateway service installation — all of which would try to mutate an immutable
# system — while leaving config mutation alone.
{
  flake.nixosModules.hermes =
    {
      config,
      lib,
      pkgs,
      ...
    }:
    let
      inherit (lib.attrsets) mapAttrsToList;
      inherit (lib.lists)
        elem
        flatten
        optional
        singleton
        ;
      inherit (lib.meta) getExe;
      inherit (lib.modules) mkIf;
      inherit (lib.options) mkEnableOption mkOption;
      inherit (lib.strings) escapeShellArgs;
      inherit (lib.types)
        bool
        nullOr
        package
        path
        port
        str
        ;

      cfg = config.services.hermes;

      settingsFormat = pkgs.formats.yaml { };

      settingsFile = settingsFormat.generate "hermes-managed-config.yaml" cfg.settings;

      isLoopback = elem cfg.dashboard.host [
        "127.0.0.1"
        "::1"
        "localhost"
      ];
    in
    {
      options.services.hermes = {
        enable = mkEnableOption "the Hermes Agent dashboard and its managed configuration";

        package = mkOption {
          type = package;
          description = ''
            The `hermes-agent` package. No default: it comes from a flake
            input rather than nixpkgs, so the host supplies it and this
            module stays input-free.
          '';
        };

        stateDir = mkOption {
          type = path;
          default = "/var/lib/hermes";
          description = "`HERMES_HOME` — config, sessions, memory and skills.";
        };

        user = mkOption {
          type = str;
          default = "hermes";
          description = "User the agent runs as.";
        };

        group = mkOption {
          type = str;
          default = "hermes";
          description = "Group the agent runs as.";
        };

        environmentFile = mkOption {
          type = nullOr path;
          default = null;
          description = ''
            Environment file read by the unit. The right home for the gateway
            credential and for `HERMES_DASHBOARD_BASIC_AUTH_PASSWORD_HASH` /
            `_SECRET`, none of which should sit in the world-readable store.
          '';
        };

        dashboard = {
          host = mkOption {
            type = str;
            default = "127.0.0.1";
            description = ''
              Bind address for the web dashboard. Hermes refuses a
              non-loopback bind with no auth provider registered — it exits
              rather than serving unauthenticated — so pair anything else
              with credentials from `environmentFile`.
            '';
          };

          port = mkOption {
            type = port;
            default = 9119;
            description = "Port the dashboard listens on.";
          };

          openFirewall = mkOption {
            type = bool;
            default = false;
            description = "Open `dashboard.port` in the firewall.";
          };
        };

        settings = mkOption {
          inherit (settingsFormat) type;
          default = { };
          example = {
            model = {
              provider = "custom";
              default = "free-heavy";
            };
          };
          description = ''
            Managed-scope configuration, rendered to
            `/etc/hermes/config.yaml`. Every key set here is pinned: Hermes
            merges this file over `~/.hermes/config.yaml` per leaf, so a key
            declared here wins and a key left out stays operator-writable.

            See Hermes' own `cli-config.yaml.example` for the key tree.
          '';
        };
      };

      config = mkIf cfg.enable {
        assertions = [
          {
            assertion = isLoopback -> (cfg.settings.dashboard.public_url or null) == null;
            message = ''
              services.hermes.settings.dashboard.public_url is set while
              services.hermes.dashboard.host is loopback. An operator-declared
              public URL engages Hermes' auth gate even on a loopback bind, so this
              combination makes the dashboard refuse to start unless an auth
              provider is configured too. Either drop public_url, or bind
              non-loopback and supply credentials.
            '';
          }

          {
            assertion =
              isLoopback
              || cfg.environmentFile != null
              || (cfg.settings.dashboard.basic_auth.password_hash or null) != null
              || (cfg.settings.dashboard.oauth.client_id or null) != null;
            message = ''
              services.hermes.dashboard.host is ${cfg.dashboard.host}, which is not
              loopback, but no auth provider can be registered: neither
              services.hermes.environmentFile (the intended home for
              HERMES_DASHBOARD_BASIC_AUTH_PASSWORD_HASH and _SECRET) nor a
              configured basic_auth password hash nor an OAuth client id. Hermes has
              no unauthenticated public-dashboard mode — it exits at startup with
              "Refusing to bind dashboard" — so this would deploy a unit that can
              only fail.
            '';
          }

          {
            assertion = !(cfg.settings.security.allow_lazy_installs or false);
            message = ''
              services.hermes.settings.security.allow_lazy_installs is on. Under Nix
              the store is read-only, so every lazy install can only fail and then
              silently disable the feature it was for. The packaged wrapper already
              sets HERMES_DISABLE_LAZY_INSTALLS; leave this off.
            '';
          }
        ]
        ++ (
          # A type cannot say "exactly one of these two keys". Hermes picks a
          # transport from whichever it finds first and says nothing about
          # the one it ignored.
          cfg.settings.mcp_servers or { }
          |> mapAttrsToList (
            name: server:
            singleton {
              assertion = (server ? url) != (server ? command);
              message = ''
                services.hermes.settings.mcp_servers.${name} must set exactly one of
                `url` (a streamable-HTTP server) or `command` (a stdio server). It
                currently sets ${if server ? url then "both" else "neither"}.
              '';
            }
            ++ singleton {
              assertion = server ? args -> server ? command;
              message = ''
                services.hermes.settings.mcp_servers.${name} sets `args` with no
                `command`, so the arguments belong to nothing.
              '';
            }
          )
          |> flatten
        );

        users.users.${cfg.user} = {
          isSystemUser = true;
          inherit (cfg) group;
          home = cfg.stateDir;
        };

        users.groups.${cfg.group} = { };

        # MANAGED SCOPE
        # `/etc/hermes` is what `managed_scope.get_managed_dir()` probes for,
        # and root ownership is the whole enforcement mechanism in its v1: the
        # layer wins over the user's config precisely because the user cannot
        # write it. /etc gives that for free.
        environment.etc."hermes/config.yaml".source = settingsFile;

        systemd.tmpfiles.rules = [
          "d ${cfg.stateDir} 0700 ${cfg.user} ${cfg.group} -"

          # Hermes reads this marker as well as HERMES_MANAGED, so an operator
          # running `hermes` by hand hits the same package-manager write lock
          # the service does, instead of being offered an update path that
          # cannot work.
          "f+ ${cfg.stateDir}/.managed 0444 ${cfg.user} ${cfg.group} - nixos"
        ];

        systemd.services.hermes-dashboard = {
          description = "Hermes Agent web dashboard";
          wantedBy = singleton "multi-user.target";
          after = singleton "network.target";

          environment = {
            HERMES_HOME = cfg.stateDir;
            HERMES_MANAGED = "nixos";
            HERMES_MANAGED_DIR = "/etc/hermes";
          };

          serviceConfig = {
            ExecStart = escapeShellArgs [
              (getExe cfg.package)
              "dashboard"

              # The packaged wrapper points HERMES_WEB_DIST at a prebuilt SPA,
              # which already suppresses the npm build; passing this makes the
              # intent explicit rather than depending on that inference.
              "--skip-build"

              # There is no browser on a headless container, and without this
              # the dashboard tries to open one on every start.
              "--no-open"

              "--host"
              cfg.dashboard.host
              "--port"
              (toString cfg.dashboard.port)
            ];

            User = cfg.user;
            Group = cfg.group;
            WorkingDirectory = cfg.stateDir;
            EnvironmentFile = optional (cfg.environmentFile != null) cfg.environmentFile;

            Restart = "on-failure";
            RestartSec = "10s";

            # Deliberately light on syscall and namespace filtering. This is an
            # agent whose entire job is running the tools its toolsets expose —
            # a shell, git, nix — so a @system-service filter or
            # RestrictNamespaces would break the product rather than contain
            # it. The boundaries that matter are the unprivileged user, the
            # read-only store, and Hermes' own approval engine.
            NoNewPrivileges = true;
            PrivateTmp = true;
            ProtectSystem = "strict";
            ProtectHome = true;
            ProtectKernelTunables = true;
            ProtectKernelModules = true;
            ProtectControlGroups = true;
            ProtectClock = true;
            LockPersonality = true;
            RestrictSUIDSGID = true;
            ReadWritePaths = singleton cfg.stateDir;
          };
        };

        networking.firewall.allowedTCPPorts = mkIf cfg.dashboard.openFirewall (
          singleton cfg.dashboard.port
        );
      };
    };
}
