{
  inputs,
  self,
  ...
}:
{
  flake.nixosConfigurations.ente-server-lxc = inputs.nixpkgs.lib.nixosSystem {
    modules = [
      "${inputs.nixpkgs}/nixos/modules/virtualisation/proxmox-lxc.nix"
      self.nixosModules.security
      self.nixosModules.shell
      self.nixosModules.nix
      self.nixosModules.nuke-default-packages
      self.nixosModules.ente-server

      (
        { lib, pkgs, ... }:
        let
          inherit (lib.lists) singleton;
        in
        {
          environment.systemPackages = singleton pkgs.git;

          shell.default = "bash";

          services.openssh.enable = false;
          services.getty.autologinUser = "root";

          xdg.sounds.enable = false;
          xdg.mime.enable = false;
          xdg.icons.enable = false;
          fonts.fontconfig.enable = false;

          services.ente-server = {
            enable = true;
            domain = "blorgydoo.com";
            s3Address = "10.0.60.10";
          };

          nixpkgs.hostPlatform = "x86_64-linux";
          system.stateVersion = "25.11";
        }
      )
    ];
  };

  flake.packages.x86_64-linux.ente-server-lxc =
    self.nixosConfigurations.ente-server-lxc.config.system.build.tarball;
}
