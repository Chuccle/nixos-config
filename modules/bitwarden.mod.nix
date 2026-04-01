{
  flake.homeModules.bitwarden =
    { pkgs, lib, ... }:
    let
      inherit (lib.lists) singleton;
    in
    {
      packages = singleton pkgs.bitwarden-desktop;
    };
}
