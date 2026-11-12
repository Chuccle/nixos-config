{ inputs, self, ... }:
{
  perSystem =
    {
      lib,
      pkgs,
      ...
    }:
    let
      inherit (lib.lists) singleton;
      treefmt = inputs.treefmt-nix.lib.evalModule pkgs (_: {
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

      statixConfig = pkgs.linkFarm "statix-config" {
        "statix.toml" = (pkgs.formats.toml { }).generate "statix.toml" {
          disabled = treefmt.config.programs.statix.disabled-lints;
        };
      };

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
        actionlint = pkgs.stdenvNoCC.mkDerivation {
          name = "actionlint-check";
          src = self;
          nativeBuildInputs = singleton pkgs.actionlint;
          buildPhase = "actionlint .github/workflows/*.yml";
          installPhase = "touch $out";
        };
        statix = pkgs.callPackage (
          { statix, stdenvNoCC }:
          stdenvNoCC.mkDerivation {
            name = "statix-check";
            src = self;
            nativeBuildInputs = singleton statix;
            buildPhase = "statix check --config ${statixConfig}/statix.toml .";
            installPhase = "touch $out";
          }
        ) { };
      };
    };
}
