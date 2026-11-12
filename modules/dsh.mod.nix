{
  flake.nixosModules.dsh =
    {
      config,
      lib,
      pkgs,
      ...
    }:
    let
      inherit (lib.lists) singleton;
      inherit (lib.meta) getExe;
      inherit (lib.modules) mkIf;
      inherit (lib.options) mkOption;
      inherit (lib.types)
        bool
        int
        listOf
        package
        str
        ;

      cfg = config.services.dsh;
    in
    {
      options.services.dsh = {
        enable = mkOption {
          type = bool;
          default = false;
          description = "Whether to run the DeepSeek Harness web UI.";
        };

        host = mkOption {
          type = str;
          default = "127.0.0.1";
          description = "Address the web UI binds to.";
        };

        port = mkOption {
          type = int;
          default = 8080;
          description = "Port the web UI binds to.";
        };

        publicUrl = mkOption {
          type = str;
          description = "Public URL the UI advertises.";
        };

        trustedHost = mkOption {
          type = str;
          description = "Host accepted in the Host header.";
        };

        package = mkOption {
          type = package;
          default = pkgs.deepseek-harness;
          description = "DeepSeek Harness package to run.";
        };

        tooling = mkOption {
          type = listOf package;
          default = [
            pkgs.bashInteractive
            pkgs.bubblewrap
          ];
          description = "Programs on the unit's PATH; bash and bubblewrap are required by name.";
        };

        user = mkOption {
          type = str;
          default = "dsh";
          description = "User the service runs as.";
        };

        group = mkOption {
          type = str;
          default = "dsh";
          description = "Group the service runs as.";
        };
      };

      config = mkIf cfg.enable {
        systemd.services.dsh = {
          description = "DeepSeek Harness web UI";

          wantedBy = singleton "multi-user.target";
          after = singleton "network-online.target";
          wants = singleton "network-online.target";

          # Everything the agent shells out to lives on the unit's PATH.
          path = cfg.tooling;

          serviceConfig = {
            Type = "simple";
            User = cfg.user;
            Group = cfg.group;
            WorkingDirectory = "/var/lib/dsh/workspace";
            StateDirectory = "dsh";
            StateDirectoryMode = "0750";

            ExecStart = "${getExe cfg.package} web --host ${cfg.host} --port ${toString cfg.port} --no-open --public-url ${cfg.publicUrl} --trusted-host ${cfg.trustedHost}";

            Restart = "on-failure";
            RestartSec = 5;

            Environment = [
              "DSH_HOME=/var/lib/dsh"
              "HOME=/var/lib/dsh"
              "XDG_CACHE_HOME=/tmp/nix-cache"
            ];

            EnvironmentFile = "-/var/lib/dsh/dsh.env";

            NoNewPrivileges = true;
            PrivateTmp = true;
            ProtectHome = true;
            ProtectSystem = "strict";
            ReadWritePaths = singleton "/var/lib/dsh";
          };
        };

        users.groups.${cfg.group} = { };

        users.users.${cfg.user} = {
          isSystemUser = true;
          inherit (cfg) group;
          home = "/var/lib/dsh";
          createHome = true;
          shell = pkgs.bash;
        };

        systemd.tmpfiles.rules = singleton "d /var/lib/dsh/workspace 0750 ${cfg.user} ${cfg.group} -";

        environment.systemPackages = singleton cfg.package ++ cfg.tooling;

        networking.firewall = {
          enable = true;
          allowedTCPPorts = singleton cfg.port;
        };
      };
    };
}
