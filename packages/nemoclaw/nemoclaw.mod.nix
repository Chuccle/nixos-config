{
  perSystem =
    { config, pkgs, ... }:
    {
      packages.nemoclaw = pkgs.callPackage ./package.nix {
        inherit (config.packages) openshell;
        openshellSdk = pkgs.callPackage ./openshell-sdk.nix { inherit (config.packages) openshell; };
      };
    };
}
