# ai-memory — the MCP memory server both agents attach to.
#
# Hermes has its own SQLite memory and opencode has none, so without something
# in the middle each agent accumulates a private, mutually invisible history.
# Run once over streamable HTTP, ai-memory is a single MCP endpoint both of
# them connect to, which makes "what did we decide about X" answerable from
# either surface.
#
# `settings` is a plain attrset rendered by `pkgs.formats.toml`. `bind` and
# `data_dir` are deliberately not set through it: both are also command-line
# flags, the flags win, and this module passes them — so putting them in the
# TOML would render keys that never take effect. `--config` likewise points at
# /etc rather than the data directory's default `config.toml`, so `ai-memory
# init` can never overwrite the generated file.
#
# Credentials stay out of the file entirely: ai-memory reads its bearer from
# `AI_MEMORY_AUTH_TOKEN` and its upstream model credential from `LLM_API_KEY`,
# both supplied through `environmentFile`.
{
  flake.nixosModules.ai-memory =
    {
      config,
      lib,
      pkgs,
      ...
    }:
    let
      inherit (lib.lists) elem optional singleton;
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

      cfg = config.services.ai-memory;

      settingsFormat = pkgs.formats.toml { };

      settingsFile = settingsFormat.generate "ai-memory-config.toml" cfg.settings;

      isLoopback = elem cfg.listen.host [
        "127.0.0.1"
        "::1"
      ];
    in
    {
      options.services.ai-memory = {
        enable = mkEnableOption "the ai-memory MCP server shared by the agents";

        package = mkOption {
          type = package;
          description = ''
            The `ai-memory` package. No default: it comes from a flake input
            rather than nixpkgs, so the host supplies it and this module stays
            input-free.
          '';
        };

        dataDir = mkOption {
          type = path;
          default = "/var/lib/ai-memory";
          description = "Root of the wiki, raw capture, index and model cache.";
        };

        user = mkOption {
          type = str;
          default = "ai-memory";
          description = "User the server runs as.";
        };

        group = mkOption {
          type = str;
          default = "ai-memory";
          description = "Group the server runs as.";
        };

        environmentFile = mkOption {
          type = nullOr path;
          default = null;
          description = ''
            Environment file read by the unit. The home for
            `AI_MEMORY_AUTH_TOKEN` — the bearer every MCP client presents —
            and for `LLM_API_KEY`, the consolidation model's credential.
          '';
        };

        listen = {
          host = mkOption {
            type = str;
            default = "127.0.0.1";
            description = ''
              Bind address. ai-memory refuses to start on a non-loopback
              address with no `AI_MEMORY_AUTH_TOKEN` configured, rather than
              serving destructive MCP tools to the network.
            '';
          };

          port = mkOption {
            type = port;
            default = 49374;
            description = "Port the MCP endpoint and web surface share.";
          };

          openFirewall = mkOption {
            type = bool;
            default = false;
            description = "Open `listen.port` in the firewall.";
          };
        };

        web.enable = mkOption {
          type = bool;
          default = false;
          description = ''
            Mount the wiki browser at `<base>/web`. The MCP endpoint at
            `<base>/mcp` is served either way; this is only the
            human-readable view of what the agents have written.
          '';
        };

        workspace = mkOption {
          type = str;
          default = "default";
          description = ''
            Workspace the server falls back to. Unlike the client subcommands
            the server cannot walk up from a caller's cwd, so this is what
            hook events with no usable one are filed under.
          '';
        };

        project = mkOption {
          type = str;
          default = "default";
          description = "Project within the workspace used as the same fallback.";
        };

        settings = mkOption {
          inherit (settingsFormat) type;
          default = { };
          example = {
            llm_provider = "openai-compat";
            embedding_provider = "none";
          };
          description = "Configuration rendered to `/etc/ai-memory/config.toml`.";
        };
      };

      config = mkIf cfg.enable {
        assertions = [
          {
            assertion = isLoopback || cfg.environmentFile != null;
            message = ''
              services.ai-memory.listen.host is ${cfg.listen.host}, which is not
              loopback, but services.ai-memory.environmentFile is unset so
              AI_MEMORY_AUTH_TOKEN cannot be provided. ai-memory refuses to bind in
              that case — "refusing unauthenticated plain HTTP on non-loopback
              address" — so this would deploy a unit that can only fail.
            '';
          }

          {
            assertion =
              (cfg.settings.llm_provider or null) != "openai-compat"
              || (cfg.settings ? llm_model && cfg.settings ? llm_base_url);
            message = ''
              services.ai-memory.settings.llm_provider is "openai-compat", which has
              no default model or endpoint: ai-memory fails with NotConfigured unless
              both settings.llm_model and settings.llm_base_url are set.
            '';
          }

          {
            assertion =
              (cfg.settings.embedding_provider or null) != "openai-compat"
              || (cfg.settings ? embedding_model && cfg.settings ? embedding_dim);
            message = ''
              services.ai-memory.settings.embedding_provider is "openai-compat", for
              which ai-memory refuses to guess: both settings.embedding_model and
              settings.embedding_dim have to be set, because dimensionality varies
              between self-hosted models.
            '';
          }

          {
            assertion = !(cfg.settings.auth.secure_cookie or false) || cfg.settings ? base_path;
            message = ''
              services.ai-memory.settings.auth.secure_cookie is on, which marks the web
              session cookie Secure. Nothing here terminates TLS, so on plain HTTP the
              browser refuses to store the cookie and web login silently never
              completes. Turn it on only when a reverse proxy is actually in front,
              which is also when settings.base_path is normally set.
            '';
          }

          {
            assertion = !(cfg.settings ? bind || cfg.settings ? data_dir);
            message = ''
              services.ai-memory.settings sets `bind` or `data_dir`, both of which the
              unit passes as command-line flags. The flags win, so the TOML values
              would be inert. Use services.ai-memory.listen and .dataDir instead.
            '';
          }
        ];

        users.users.${cfg.user} = {
          isSystemUser = true;
          inherit (cfg) group;
          home = cfg.dataDir;
        };

        users.groups.${cfg.group} = { };

        environment.etc."ai-memory/config.toml".source = settingsFile;

        systemd.tmpfiles.rules = singleton "d ${cfg.dataDir} 0700 ${cfg.user} ${cfg.group} -";

        systemd.services.ai-memory = {
          description = "ai-memory MCP server";
          wantedBy = singleton "multi-user.target";
          after = singleton "network.target";

          environment = {
            HOME = cfg.dataDir;
            AI_MEMORY_HOME = cfg.dataDir;
            AI_MEMORY_NO_VERSION_CHECK = "1";
            AI_MEMORY_SKIP_SELF_UPGRADE = "1";
          };

          serviceConfig = {
            ExecStart = escapeShellArgs (
              [
                (getExe cfg.package)
                "--config"
                "/etc/ai-memory/config.toml"
                "--data-dir"
                cfg.dataDir
                "serve"
                "--transport"
                "http"
                "--bind"
                "${cfg.listen.host}:${toString cfg.listen.port}"
                "--workspace"
                cfg.workspace
                "--project"
                cfg.project
              ]
              ++ optional cfg.web.enable "--enable-web"
            );

            User = cfg.user;
            Group = cfg.group;
            WorkingDirectory = cfg.dataDir;
            EnvironmentFile = optional (cfg.environmentFile != null) cfg.environmentFile;

            Restart = "on-failure";
            RestartSec = "10s";

            # Unlike the two agents this is a plain server: it shells out to
            # git and nothing else, so it gets the full profile.
            NoNewPrivileges = true;
            PrivateDevices = true;
            PrivateTmp = true;
            ProtectClock = true;
            ProtectControlGroups = true;
            ProtectHome = true;
            ProtectHostname = true;
            ProtectKernelLogs = true;
            ProtectKernelModules = true;
            ProtectKernelTunables = true;
            ProtectProc = "invisible";
            ProtectSystem = "strict";
            RestrictNamespaces = true;
            RestrictRealtime = true;
            RestrictSUIDSGID = true;
            LockPersonality = true;
            CapabilityBoundingSet = "";

            RestrictAddressFamilies = [
              "AF_INET"
              "AF_INET6"
              "AF_UNIX"
            ];

            SystemCallFilter = [
              "@system-service"
              "~@privileged"
              "~@resources"
            ];

            ReadWritePaths = singleton cfg.dataDir;
          };
        };

        networking.firewall.allowedTCPPorts = mkIf cfg.listen.openFirewall (singleton cfg.listen.port);
      };
    };
}
