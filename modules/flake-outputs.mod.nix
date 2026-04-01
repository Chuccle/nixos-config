{
  lib,
  moduleLocation,
  ...
}:
let
  inherit (lib.attrsets) mapAttrs;
  inherit (lib.options) mkOption;
  inherit (lib.types) deferredModule lazyAttrsOf;
in
{
  options.flake.homeModules = mkOption {
    type = lazyAttrsOf deferredModule;
    default = { };
    apply = mapAttrs (
      name: value: {
        _file = "${toString moduleLocation}#homeModules.${name}";
        imports = lib.singleton value;
      }
    );
    description = "Home modules.";
  };
}
