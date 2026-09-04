{ inputs, self, ... }:
{
  perSystem =
    {
      lib,
      pkgs,
      system,
      ...
    }:
    let
      inherit (lib.attrsets) filterAttrs mapAttrs' nameValuePair;
      inherit (lib.lists) singleton;
      treefmt = inputs.treefmt-nix.lib.evalModule pkgs (_: {
        projectRootFile = "flake.nix";
        programs = {
          nixfmt.enable = true;
          deadnix.enable = true;
          black.enable = true;
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
          statix.enable = true;
        };
      });

      hostChecks =
        self.nixosConfigurations
        |> filterAttrs (_name: cfg: cfg.config.nixpkgs.hostPlatform.system == system)
        |> mapAttrs' (name: cfg: nameValuePair "host-${name}" cfg.config.system.build.toplevel);
    in
    {
      formatter = treefmt.config.build.wrapper;
      devShells.default = pkgs.mkShell {
        packages = [
          treefmt.config.build.wrapper
          pkgs.deadnix
          pkgs.direnv
          pkgs.nil
          pkgs.nix-direnv
          pkgs.nixfmt
          pkgs.statix
        ];
      };
      checks = {
        formatting = treefmt.config.build.check self;
        deadnix = pkgs.callPackage (
          { deadnix, stdenvNoCC }:
          stdenvNoCC.mkDerivation {
            name = "deadnix-check";
            src = self;
            nativeBuildInputs = singleton deadnix;
            buildPhase = "deadnix --fail .";
            installPhase = "touch $out";
          }
        ) { };
        statix = pkgs.callPackage (
          { statix, stdenvNoCC }:
          stdenvNoCC.mkDerivation {
            name = "statix-check";
            src = self;
            nativeBuildInputs = singleton statix;
            buildPhase = "statix check .";
            installPhase = "touch $out";
          }
        ) { };
      }
      // hostChecks;
    };
}
