{ inputs, ... }:
{
  perSystem =
    { lib, pkgs, ... }:
    let
      inherit (pkgs.lib.lists) singleton;
    in
    {
      options.dev.treefmt = lib.mkOption {
        type = lib.types.raw;
        description = "The shared treefmt configuration.";
      };

      config.dev.treefmt = inputs.treefmt-nix.lib.evalModule pkgs (_: {
        projectRootFile = "flake.nix";
        programs = {
          nixfmt.enable = true;
          deadnix.enable = true;
          prettier = {
            enable = true;
            package = pkgs.prettier;
            includes = [
              "*.yml"
              "*.yaml"
              "*.json"
              "*.md"
            ];
          };
          statix = {
            enable = true;
            disabled-lints = singleton "repeated_keys";
          };
        };
      });
    };
}
