# Live-ISO variants of the desktop stacks, meant to be chucked into a VM:
#   nix build .#nixosConfigurations.iso-tahoe.config.system.build.isoImage
#   nix build .#nixosConfigurations.iso-win95.config.system.build.isoImage
# Built on the installer-CD base (live `nixos` user, enableAllHardware — which
# carries the virtio drivers a VM needs), plus one composed desktop stack. NOTE:
# not installation-cd-minimal — that pulls in profiles/minimal.nix and disables
# fontconfig, which no GUI toolkit survives.
{
  config,
  inputs,
  self,
  ...
}:
let
  # Desktop registries are internal flake-parts options (not flake outputs), so
  # they are read from `config`, not `self`.
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
            self.homeModules.foot
            self.homeModules.ida-pro
          ]
          ++ desktopHome;
        }
        (
          { lib, pkgs, ... }:
          {
            isoImage.edition = edition;

            # LIVE SESSION
            # installation-device provides the passwordless `nixos` user;
            # autologin straight into the composed compositor and give hjem
            # that user so the desktop home modules apply. IDA rides along for
            # testing the package in the live session.
            desktop.autoLoginUser = "nixos";
            home.users.nixos = {
              ida-pro.package = self.packages.${pkgs.stdenv.hostPlatform.system}.ida-pro;
            };

            # installation-device defaults to wpa_supplicant, which conflicts
            # with NetworkManager.
            networking.wireless.enable = lib.mkForce false;

            # installation-device pulls in ZFS support so the installer can
            # target ZFS root filesystems, but nixpkgs' zfs-kernel module is
            # marked broken against the CachyOS kernel (too new for the
            # bundled ZFS release) — these live ISOs don't need ZFS, so drop
            # it rather than eval-failing on the cachy module.
            boot.supportedFilesystems.zfs = lib.mkForce false;

            # VM GUEST
            services.qemuGuest.enable = true;
            services.spice-vdagentd.enable = true;

            # installation-cd-base pins stateVersion and forces the
            # image-media fileSystems, so neither is set here.
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
    ];
  };

  # WIN95
  flake.nixosConfigurations.iso-win95 = mkIso {
    edition = "win95";

    desktopSystem = [
      desktopModules.labwc
      desktopModules.win95-panel
      desktopModules.qt
      desktopModules.theme-win95
    ];

    desktopHome = [
      desktopHomeModules.labwc
      desktopHomeModules.win95-panel
      desktopHomeModules.gtk
      desktopHomeModules.qt
      desktopHomeModules.cursor-icons
    ];
  };
}
