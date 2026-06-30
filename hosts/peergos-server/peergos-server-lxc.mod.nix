{
  lib,
  inputs,
  self,
  ...
}:
let
  inherit (lib.lists) singleton;
  modules = [
    "${inputs.nixpkgs}/nixos/modules/virtualisation/proxmox-lxc.nix"
    self.nixosModules.security
    self.nixosModules.shell
    self.nixosModules.nix
    self.nixosModules.nuke-default-packages
    self.nixosModules.peergos-service
  ]
  ++ singleton (
    { pkgs, ... }:
    {
      shell.default = "bash";

      environment.systemPackages = singleton pkgs.git;

      services.peergos-service = {
        subCommand = "daemon";
        extraArgs = [
          "-listen-host"
          "0.0.0.0"
          "-port"
          "8000"
          "-public-domain"
          "peergos.blorg.lan"
          "-public-server"
          "true"
        ];
      };

      networking.firewall.allowedTCPPorts = [
        8000
        4001
      ];
      networking.firewall.allowedUDPPorts = singleton 4001;

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
  flake.nixosConfigurations.peergos-server-lxc = inputs.nixpkgs.lib.nixosSystem {
    inherit modules;
  };

  flake.packages.x86_64-linux.peergos-server-lxc =
    self.nixosConfigurations.peergos-server-lxc.config.system.build.tarball;
}
