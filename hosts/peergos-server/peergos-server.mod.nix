# Headless server configuration for Peergos.
# This is a separate configuration from the desktop one,
# as it has different requirements and should be kept minimal.
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
  flake.nixosConfigurations.peergos-server = inputs.nixpkgs.lib.nixosSystem {
    specialArgs = { inherit self inputs; };

    modules =
      attrValues self.nixosModules

      ++ singleton {
        networking.hostName = "peergos-server";

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
