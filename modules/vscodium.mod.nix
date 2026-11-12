{
  flake.homeModules.vscodium =
    { lib, pkgs, ... }:
    let
      inherit (lib.lists) singleton;
    in
    {
      packages = singleton pkgs.vscodium;
    };
}
