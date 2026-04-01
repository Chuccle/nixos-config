{
  flake.homeModules.btop =
    { pkgs, lib, ... }:
    let
      inherit (lib.lists) singleton;
    in
    {
      packages = singleton pkgs.btop;
    };
}
