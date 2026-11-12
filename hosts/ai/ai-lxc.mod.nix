{
  inputs,
  self,
  ...
}:
let
  fqdn = "ai.blorg.lan";
in
{
  flake.nixosConfigurations.ai-lxc = inputs.nixpkgs.lib.nixosSystem {
    modules = [
      "${inputs.nixpkgs}/nixos/modules/virtualisation/proxmox-lxc.nix"
      self.nixosModules.security
      self.nixosModules.shell
      self.nixosModules.nix
      self.nixosModules.nuke-default-packages
      self.nixosModules.dsh

      (
        { pkgs, ... }:
        {
          shell.default = "bash";

          xdg.sounds.enable = false;
          xdg.mime.enable = false;
          xdg.icons.enable = false;
          fonts.fontconfig.enable = false;

          services.getty.autologinUser = "root";
          services.openssh.enable = false;

          # dsh spawns bash for the shell tool and bwrap for the sandbox, both
          # by name, so both must be on the unit's PATH. Its glob/grep tools use
          # a ripgrep binary bundled in the package, not a system one. git, gh
          # and ssh cover repository work, node runs the worktree tooling;
          # coreutils, findutils, grep, sed and systemd already arrive via
          # systemd.defaultPath.
          services.dsh = {
            enable = true;
            host = "10.0.30.10";
            port = 8080;
            publicUrl = "https://${fqdn}";
            trustedHost = fqdn;

            tooling = with pkgs; [
              bashInteractive
              bubblewrap
              git
              gh
              nodejs_24
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
          };

          nixpkgs.hostPlatform = "x86_64-linux";
          system.stateVersion = "25.11";
        }
      )
    ];
  };

  flake.packages.x86_64-linux.ai-lxc = self.nixosConfigurations.ai-lxc.config.system.build.tarball;
}
