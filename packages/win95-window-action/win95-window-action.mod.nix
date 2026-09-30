{
  perSystem =
    { pkgs, ... }:
    {
      packages.win95-window-action = pkgs.callPackage ./package.nix { };
    };
}
