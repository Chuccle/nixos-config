{
  perSystem =
    { pkgs, ... }:
    {
      packages.openshell = pkgs.callPackage ./package.nix {
        companions = [
          (pkgs.callPackage ./package.nix { crate = "openshell-server"; })
          (pkgs.pkgsStatic.callPackage ./package.nix { crate = "openshell-sandbox"; })
        ];
      };
    };
}
