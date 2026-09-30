{
  config,
  inputs,
  self,
  ...
}:
let
  inherit (config) desktopModules desktopHomeModules;

  mkIso =
    {
      desktopHome,
      desktopSystem,
      edition,
    }:
    inputs.nixpkgs.lib.nixosSystem {
      modules = [
        "${inputs.nixpkgs}/nixos/modules/installer/cd-dvd/installation-cd-base.nix"

        self.nixosModules.desktop
        self.nixosModules.theme
        self.nixosModules.home
        self.nixosModules.fonts
        self.nixosModules.networkmanager
        self.nixosModules.packages-debugging
        self.nixosModules.cachy

        desktopModules.login
      ]
      ++ desktopSystem
      ++ [
        {
          home.extraModules = [
            self.homeModules.home
            self.homeModules.ghostty
            self.homeModules.file-explorer
            self.homeModules.helium
            self.homeModules.ida-pro
          ]
          ++ desktopHome;
        }
        (
          { lib, pkgs, ... }:
          {
            isoImage.edition = edition;

            # LIVE SESSION
            desktop.autoLoginUser = "nixos";
            home.users.nixos = {
              ida-pro.package = self.packages.${pkgs.stdenv.hostPlatform.system}.ida-pro;

              # Passwordless live sessions have no unlocked login keyring.
              helium.commandLineArgs = [
                "--password-store=basic"
                "--gtk-version=3"
              ];
            };

            networking.wireless.enable = lib.mkForce false;

            boot.supportedFilesystems.zfs = lib.mkForce false;

            # VM GUEST
            services.qemuGuest.enable = true;
            services.spice-vdagentd.enable = true;

            nixpkgs.hostPlatform = "x86_64-linux";
          }
        )
      ];
    };
in
{
  # TAHOE (liquid glass)
  flake.nixosConfigurations.iso-tahoe = mkIso {
    edition = "tahoe";

    desktopSystem = [
      desktopModules.niri
      desktopModules.dms
      desktopModules.qt
      desktopModules.theme-tahoe
    ];

    desktopHome = [
      desktopHomeModules.niri
      desktopHomeModules.dms
      desktopHomeModules.gtk
      desktopHomeModules.qt
      desktopHomeModules.cursor-icons
      desktopHomeModules.tahoe-live
    ];
  };

  # WIN95
  flake.nixosConfigurations.iso-win95 = mkIso {
    edition = "win95";

    desktopSystem = [
      desktopModules.niri
      desktopModules.win95-panel
      desktopModules.qt
      desktopModules.theme-win95
    ];

    desktopHome = [
      desktopHomeModules.niri
      desktopHomeModules.win95-panel
      desktopHomeModules.gtk
      desktopHomeModules.qt
      desktopHomeModules.cursor-icons
    ];
  };
}
