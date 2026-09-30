{
  edition,
  publicKey,
  source,
}:
let
  flake = builtins.getFlake "path:${source}";
  system = flake.nixosConfigurations."iso-${edition}".extendModules {
    modules = [
      flake.nixosModules.desktop-inspection
      {
        inspection.enable = true;
        inspection.publicKey = publicKey;
      }
    ];
  };
in
system.config.system.build.isoImage
