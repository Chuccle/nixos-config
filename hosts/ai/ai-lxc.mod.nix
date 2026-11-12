{
  inputs,
  lib,
  self,
  ...
}:
let
  domain = "blorg.lan";
  hostName = "ai";
  fqdn = "${hostName}.${domain}";
in
{
  flake.nixosConfigurations.ai-lxc = inputs.nixpkgs.lib.nixosSystem {
    modules = [
      "${inputs.nixpkgs}/nixos/modules/virtualisation/proxmox-lxc.nix"
      self.nixosModules.security
      self.nixosModules.shell
      self.nixosModules.nix
      self.nixosModules.nuke-default-packages

      (
        { pkgs, ... }:
        let
          inherit (lib.lists) singleton;
          inherit (lib.meta) getExe;
          dsh = pkgs.deepseek-harness;

          # dsh spawns bash for the shell tool and bwrap for the sandbox, both
          # by name, so both must be on the unit's PATH. Its glob/grep tools use
          # a ripgrep binary bundled in the package, not a system one. git and
          # ssh cover repository work; coreutils, findutils, grep, sed and
          # systemd already arrive via systemd.defaultPath.
          tooling = with pkgs; [
            bashInteractive
            bubblewrap
            git
            openssh
            curl
            jq
            nix
            gawk
            python3
            gnumake
            gnutar
            gzip
            xz
            file
            which
          ];
        in
        {
          systemd.services.dsh = {
            description = "DeepSeek Harness web UI";

            wantedBy = singleton "multi-user.target";
            after = singleton "network-online.target";
            wants = singleton "network-online.target";

            # Everything the agent shells out to lives on the unit's PATH.
            path = tooling;

            serviceConfig = {
              Type = "simple";
              User = "dsh";
              Group = "dsh";
              WorkingDirectory = "/var/lib/dsh/workspace";
              StateDirectory = "dsh";
              StateDirectoryMode = "0750";

              ExecStart = "${getExe dsh} web --host 10.0.30.10 --port 8080 --no-open --public-url https://${fqdn} --trusted-host ${fqdn}";

              Restart = "on-failure";
              RestartSec = 5;

              Environment = [
                "DSH_HOME=/var/lib/dsh"
                "HOME=/var/lib/dsh"
                # nix's fetcher cache must land somewhere the sandbox allows.
                "XDG_CACHE_HOME=/tmp/nix-cache"
              ];

              # Optional root-readable fallback for DEEPSEEK_API_KEY. The value
              # stays outside the Nix store. The UI-managed .credentials.yaml
              # still takes precedence when it contains the key.
              EnvironmentFile = "-/var/lib/dsh/dsh.env";

              NoNewPrivileges = true;
              PrivateTmp = true;
              ProtectHome = true;
              ProtectSystem = "strict";
              ReadWritePaths = singleton "/var/lib/dsh";
            };
          };

          users.groups.dsh = { };

          users.users.dsh = {
            isSystemUser = true;
            group = "dsh";
            home = "/var/lib/dsh";
            createHome = true;
            shell = pkgs.bash;
          };

          systemd.tmpfiles.rules = singleton "d /var/lib/dsh/workspace 0750 dsh dsh -";

          shell.default = "bash";

          xdg.sounds.enable = false;
          xdg.mime.enable = false;
          xdg.icons.enable = false;
          fonts.fontconfig.enable = false;

          networking.firewall = {
            enable = true;
            allowedTCPPorts = singleton 8080;
          };

          services.getty.autologinUser = "root";

          services.openssh.enable = false;

          environment.systemPackages = singleton dsh ++ tooling;

          nixpkgs.hostPlatform = "x86_64-linux";
          system.stateVersion = "25.11";
        }
      )
    ];
  };

  flake.packages.x86_64-linux.ai-lxc = self.nixosConfigurations.ai-lxc.config.system.build.tarball;
}
