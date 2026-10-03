{ lib, moduleLocation, ... }:
let
  inherit (lib.attrsets) mapAttrs optionalAttrs;
  inherit (lib.lists) singleton;
  inherit (lib.options) mkOption;
  inherit (lib.types) deferredModule lazyAttrsOf;

  wrap =
    kind: name: value:
    {
      _file = "${toString moduleLocation}#${kind}.${name}";
      imports = singleton value;
    }
    // optionalAttrs (value ? meta) {
      inherit (value) meta;
    };
in
{
  options.flake.homeModules = mkOption {
    type = lazyAttrsOf deferredModule;
    default = { };
    apply = mapAttrs (wrap "homeModules");
    description = "Home modules.";
  };
}
