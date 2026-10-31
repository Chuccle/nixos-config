{ inputs, self, ... }:
{
  flake.nixosConfigurations.blorg-live = self.nixosConfigurations.blorg.extendModules {
    modules = [
      "${inputs.nixpkgs}/nixos/modules/installer/cd-dvd/installation-cd-base.nix"

      (
        { lib, ... }:
        let
          inherit (lib.modules) mkForce;
        in
        {
          networking.hostName = mkForce "blorg-live";

          boot.loader.systemd-boot.enable = mkForce false;
          boot.loader.efi.canTouchEfiVariables = mkForce false;
          boot.loader.timeout = mkForce 10;
          boot.zfs.forceImportRoot = false;

          environment.defaultPackages = mkForce [ ];

          services.displayManager = {
            autoLogin = {
              enable = true;
              user = "desktop";
            };

            defaultSession = "niri";
          };

          users.users.desktop.initialHashedPassword = "";

          isoImage = {
            edition = "blorg";
            makeBiosBootable = false;
          };
        }
      )
    ];
  };

  flake.packages.x86_64-linux.blorg-live =
    self.nixosConfigurations.blorg-live.config.system.build.isoImage;
}
