{
  flake.homeModules.bitwarden =
    { lib, pkgs, ... }:
    let
      inherit (lib.lists) singleton;
    in
    {
      packages = singleton pkgs.bitwarden-desktop;
    };

  flake.nixosModules.bitwarden =
    { lib, ... }:
    let
      inherit (lib.strings) getName;
    in
    {
      nixpkgs.config.allowInsecurePredicate = pkg: getName pkg == "electron";
    };
}
