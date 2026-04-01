# This is the NixOS configuration for the "box" host.
# It includes all the necessary modules and settings to run a desktop environment with NetworkManager and a user named "box".
# This configuration is designed to be modular
{
  self,
  inputs,
  lib,
  ...
}:
let
  inherit (lib.attrsets) attrValues;
  inherit (lib.lists) singleton;

in
{
  flake.nixosConfigurations.box = inputs.nixpkgs.lib.nixosSystem {
    specialArgs = { inherit self inputs; };

    modules =
      attrValues self.nixosModules
      ++ singleton {
        home.extraModules = attrValues self.homeModules;
      }
      ++ singleton {
        networking.hostName = "box";

        users.users.box = {
          name = "box";
          isNormalUser = true;
        };
        home.users.box = { };

        # DEFAULT SHELL
        shell.default = "nushell";

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
      };
  };
}
