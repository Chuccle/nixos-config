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
      # bitwarden-desktop bundles Electron, which nixpkgs periodically marks
      # EOL/insecure. Permit it by name so version bumps don't reintroduce the
      # failure.
      nixpkgs.config.allowInsecurePredicate = pkg: getName pkg == "electron";
    };
}
