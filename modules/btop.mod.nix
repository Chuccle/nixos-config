{
  flake.homeModules.btop =
    { lib, pkgs, ... }:
    let
      inherit (lib.lists) singleton;
    in
    {
      packages = singleton pkgs.btop;
    };
}
