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
        networking.networkmanager.enable = true;

        users.users.box = {
          name = "box";
          isNormalUser = true;
        };

        # DEFAULT SHELL
        shell.default = "nushell";

        # DESKTOP
        desktop.environment = "niri";
        desktop.theme = "liquid-glass";

        nixpkgs.hostPlatform = "x86_64-linux";
        system.stateVersion = "25.11";
      };
  };
}
