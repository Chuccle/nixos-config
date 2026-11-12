{ self, ... }:
{
  flake.nixosModules.steam =
    { lib, ... }:
    let
      inherit (lib.lists) singleton;
    in
    {
      imports = singleton self.nixosModules.unfree;

      allowedUnfreePackageNames = [
        "steam"
        "steam-unwrapped"
        "steam-original"
        "steam-run"
      ];

      programs.steam.enable = true;
    };
}
