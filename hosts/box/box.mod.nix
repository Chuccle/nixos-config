# This is the NixOS configuration for the "box" host.
# It includes all the necessary modules and settings to run a desktop environment with NetworkManager and a user named "box".
# This configuration is designed to be modular
{
  config,
  inputs,
  lib,
  self,
  ...
}:
let
  inherit (lib.attrsets) attrValues removeAttrs;
  inherit (lib.lists) singleton;
  inherit (lib.trivial) flip;

  # Desktop registries are internal flake-parts options (not flake outputs), so
  # they are read from `config`, not `self`.
  inherit (config) desktopModules desktopHomeModules;

  # DESKTOP STACK
  # Tahoe = niri + DankMaterialShell, themed tahoe, with shared GTK/Qt/cursor
  # adapters. Composed explicitly from the pure desktop modules — nothing
  # self-gates, and swapping the stack is editing these two lists.
  desktopSystem = [
    desktopModules.niri
    desktopModules.dms
    desktopModules.login
    desktopModules.theme-tahoe
  ];

  desktopHome = [
    desktopHomeModules.niri
    desktopHomeModules.dms
    desktopHomeModules.gtk
    desktopHomeModules.qt
    desktopHomeModules.cursor-icons
  ];

  modules =
    (self.nixosModules |> flip removeAttrs (singleton "peergos-service") |> attrValues)
    ++ desktopSystem
    ++ singleton {
      home.extraModules = attrValues self.homeModules ++ desktopHome;
    }
    ++ singleton (
      { pkgs, ... }:
      {
        networking.hostName = "box";

        users.users.box = {
          name = "box";
          isNormalUser = true;
        };
        home.users.box = {
          ida-pro.package = self.packages.${pkgs.stdenv.hostPlatform.system}.ida-pro;
        };

        # DEFAULT SHELL
        shell.default = "nushell";

        # DESKTOP
        # Autologin into the box user; the session command is published by the
        # composed compositor (niri).
        desktop.autoLoginUser = "box";

        fileSystems."/" = {
          device = "/dev/disk/by-label/nixos";
          fsType = "ext4";
        };

        fileSystems."/boot" = {
          device = "/dev/disk/by-label/boot";
          fsType = "vfat";
        };

        nixpkgs.hostPlatform = "x86_64-linux";
        system.stateVersion = "25.11";
      }
    );
in
{
  flake.nixosConfigurations.box = inputs.nixpkgs.lib.nixosSystem {
    inherit modules;
  };
}
