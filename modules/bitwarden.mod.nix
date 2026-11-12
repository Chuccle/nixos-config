{
  flake.homeModules.bitwarden =
    { lib, pkgs, ... }:
    let
      inherit (lib.lists) singleton;
    in
    {
      packages = singleton pkgs.bitwarden-desktop;
    };
}
