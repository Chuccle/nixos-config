# opencode — the headless server.
#
# `settings` is a plain attrset rendered by `pkgs.formats.json` and handed to
# the binary through `OPENCODE_CONFIG`. The format's type does the type
# checking; opencode's own schema stays opencode's problem, which is the only
# arrangement that survives a release where it changes.
#
# TWO THINGS WORTH KNOWING ABOUT HOW OPENCODE READS CONFIG
#
#   * `server.hostname` / `server.port` / `server.cors` are read from the
#     *global* config only (`Config.getGlobal()` in the serve command's option
#     resolver), never from the file `OPENCODE_CONFIG` points at. Setting them
#     in `settings` renders a key that does nothing, so the bind is passed as
#     command-line flags instead — which take precedence over every config
#     source anyway.
#   * `serve` resolves a project per request from the `x-opencode-directory`
#     header, and a project-level `opencode.json` merges *over*
#     `OPENCODE_CONFIG`. This file is therefore a strong default, not a pin —
#     unlike Hermes' managed scope, opencode has no administrator-wins layer.
{
  flake.nixosModules.opencode =
    {
      config,
      lib,
      pkgs,
      ...
    }:
    let
      inherit (lib.attrsets) mapAttrsToList;
      inherit (lib.lists)
        concatMap
        elem
        filter
        flatten
        optional
        singleton
        ;
      inherit (lib.meta) getExe;
      inherit (lib.modules) mkIf;
      inherit (lib.options) mkEnableOption mkOption;
      inherit (lib.strings) concatStringsSep escapeShellArgs;
      inherit (lib.types)
        bool
        listOf
        nullOr
        package
        path
        port
        str
        ;

      cfg = config.services.opencode;

      settingsFormat = pkgs.formats.json { };

      settingsFile = settingsFormat.generate "opencode.json" cfg.settings;

      isLoopback = elem cfg.listen.host [
        "127.0.0.1"
        "::1"
      ];
    in
    {
      options.services.opencode = {
        enable = mkEnableOption "the headless opencode server and its configuration";

        package = mkOption {
          type = package;
          description = ''
            The `opencode` package. No default: it comes from a flake input
            rather than nixpkgs, so the host supplies it and this module stays
            input-free.
          '';
        };

        stateDir = mkOption {
          type = path;
          default = "/var/lib/opencode";
          description = ''
            `HOME` for the service, and the root of its XDG directories.
            opencode writes sessions, snapshots, auth and installed plugin
            dependencies here.
          '';
        };

        user = mkOption {
          type = str;
          default = "opencode";
          description = "User the server runs as.";
        };

        group = mkOption {
          type = str;
          default = "opencode";
          description = "Group the server runs as.";
        };

        environmentFile = mkOption {
          type = nullOr path;
          default = null;
          description = ''
            Environment file read by the unit. The home for
            `OPENCODE_SERVER_PASSWORD` and for whatever variable a provider's
            `apiKey` reads through `{env:NAME}`.
          '';
        };

        listen = {
          host = mkOption {
            type = str;
            default = "127.0.0.1";
            description = ''
              Bind address, passed as `--hostname`. opencode's HTTP surface is
              only authenticated when `OPENCODE_SERVER_PASSWORD` is set — it
              warns and serves anyway when it is not — so a non-loopback bind
              needs `environmentFile`.
            '';
          };

          port = mkOption {
            type = port;
            default = 4096;
            description = "Port, passed as `--port`.";
          };

          cors = mkOption {
            type = listOf str;
            default = [ ];
            description = "Extra origins allowed by CORS, passed as `--cors`.";
          };

          openFirewall = mkOption {
            type = bool;
            default = false;
            description = "Open `listen.port` in the firewall.";
          };
        };

        settings = mkOption {
          inherit (settingsFormat) type;
          default = { };
          example = {
            model = "litellm/free-heavy";
            autoupdate = false;
          };
          description = ''
            Configuration rendered to `/etc/opencode/opencode.json` and handed
            to the server through `OPENCODE_CONFIG`. It beats the global
            config; a project-level `opencode.json` still beats it.
          '';
        };
      };

      config = mkIf cfg.enable {
        assertions = [
          {
            assertion = !(cfg.settings.autoupdate or false);
            message = ''
              services.opencode.settings.autoupdate is on. The binary lives in the
              read-only Nix store, so a self-update can only fail and a notification
              only nags about a version this host cannot install. Set it to false and
              bump the flake input instead.
            '';
          }

          {
            assertion = isLoopback || cfg.environmentFile != null;
            message = ''
              services.opencode.listen.host is ${cfg.listen.host}, which is not
              loopback, but services.opencode.environmentFile is unset so
              OPENCODE_SERVER_PASSWORD cannot be provided. opencode does not refuse
              to start without it — it prints a warning and serves the whole API,
              including the bash tool, unauthenticated.
            '';
          }

          {
            assertion = !(cfg.settings ? server);
            message = ''
              services.opencode.settings.server is set, but `serve` reads its bind
              from the *global* config only — never from the file OPENCODE_CONFIG
              points at — so nothing here would take effect. Use
              services.opencode.listen instead, which is passed as flags.
            '';
          }
        ]
        ++ (
          # opencode discriminates its MCP config union on `type` and drops
          # the keys belonging to the other arm, silently.
          cfg.settings.mcp or { }
          |> mapAttrsToList (
            name: server:
            let
              local = [
                "command"
                "cwd"
                "environment"
              ];

              remote = [
                "headers"
                "oauth"
                "url"
              ];

              stray =
                if server.type or null == "local" then
                  remote
                else if server.type or null == "remote" then
                  local
                else
                  [ ];

              strayPresent = filter (key: server ? ${key}) stray;
            in
            singleton {
              assertion = elem (server.type or null) [
                "local"
                "remote"
              ];
              message = ''
                services.opencode.settings.mcp.${name} must set `type` to "local" or
                "remote". opencode discriminates its config union on that key, so
                without it the whole entry is rejected.
              '';
            }
            ++ singleton {
              assertion = strayPresent == [ ];
              message = ''
                services.opencode.settings.mcp.${name} has type = "${server.type or ""}"
                but sets ${concatStringsSep ", " strayPresent}, which belong to the
                other transport. opencode drops them, so those settings would
                silently do nothing.
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

        environment.etc."opencode/opencode.json".source = settingsFile;

        systemd.tmpfiles.rules = singleton "d ${cfg.stateDir} 0700 ${cfg.user} ${cfg.group} -";

        systemd.services.opencode = {
          description = "opencode headless server";
          wantedBy = singleton "multi-user.target";
          after = singleton "network.target";

          environment = {
            HOME = cfg.stateDir;
            OPENCODE_CONFIG = "/etc/opencode/opencode.json";

            # opencode's own directories follow XDG. Pinning them under
            # stateDir keeps everything it writes in one place the unit can be
            # granted, rather than scattered across a home directory that
            # ProtectSystem would otherwise have to open up.
            XDG_CACHE_HOME = "${cfg.stateDir}/cache";
            XDG_CONFIG_HOME = "${cfg.stateDir}/config";
            XDG_DATA_HOME = "${cfg.stateDir}/share";
            XDG_STATE_HOME = "${cfg.stateDir}/state";
          };

          serviceConfig = {
            ExecStart = escapeShellArgs (
              [
                (getExe cfg.package)
                "serve"
                "--hostname"
                cfg.listen.host
                "--port"
                (toString cfg.listen.port)
              ]
              ++ concatMap (origin: [
                "--cors"
                origin
              ]) cfg.listen.cors
            );

            User = cfg.user;
            Group = cfg.group;
            WorkingDirectory = cfg.stateDir;
            EnvironmentFile = optional (cfg.environmentFile != null) cfg.environmentFile;

            Restart = "on-failure";
            RestartSec = "10s";

            # Same reasoning as the Hermes unit: this is a coding agent whose
            # tools are a shell and a filesystem, so syscall and namespace
            # filtering would break it rather than contain it. The boundaries
            # are the unprivileged user, the read-only store and opencode's own
            # permission engine.
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

        networking.firewall.allowedTCPPorts = mkIf cfg.listen.openFirewall (singleton cfg.listen.port);
      };
    };
}
