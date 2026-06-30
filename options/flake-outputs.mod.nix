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
    # Preserve meta.
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

  # Desktop-stack modules are pure and mutually exclusive, so they live outside
  # the blanket-imported namespaces above: a host composes the ones it wants and
  # nothing is ever auto-applied. This is where the "complexity at the top level"
  # lands — selection is composition, not a runtime gate.
  options.desktopModules = mkOption {
    type = lazyAttrsOf deferredModule;
    default = { };
    apply = mapAttrs (wrap "desktopModules");
    description = "Pure desktop-stack NixOS modules, composed explicitly by hosts.";
  };

  options.desktopHomeModules = mkOption {
    type = lazyAttrsOf deferredModule;
    default = { };
    apply = mapAttrs (wrap "desktopHomeModules");
    description = "Pure desktop-stack home modules, composed explicitly by hosts.";
  };
}
