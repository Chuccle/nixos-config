{ inputs, self, ... }:
{
  perSystem =
    { pkgs, ... }:
    let
      statixSrc = pkgs.fetchFromGitHub {
        owner = "oppiliappan";
        repo = "statix";
        rev = "e9df54ce918457f151d2e71993edeca1a7af0132";
        hash = "sha256-duH6Il124g+CdYX+HCqOGnpJxyxOCgWYcrcK0CBnA2M=";
      };
      statix' = pkgs.statix.overrideAttrs (_o: {
        version = "0-unstable-e9df54c";
        src = statixSrc;
        cargoDeps = pkgs.rustPlatform.importCargoLock {
          lockFile = statixSrc + "/Cargo.lock";
          allowBuiltinFetchGit = true;
        };
        doInstallCheck = false;
      });
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
            ];
          };
          statix = {
            enable = true;
            package = statix';
          };
        };
      });
    in
    {
      formatter = treefmt.config.build.wrapper;
      devShells.default = pkgs.mkShell {
        packages = [
          treefmt.config.build.wrapper
          statix'
          pkgs.deadnix
          pkgs.nil
          pkgs.nixfmt
        ];
      };
      checks = {
        formatting = treefmt.config.build.check self;
        deadnix = pkgs.stdenvNoCC.mkDerivation {
          name = "deadnix-check";
          src = self;
          nativeBuildInputs = [ pkgs.deadnix ];
          buildPhase = "deadnix --fail .";
          installPhase = "touch $out";
        };
        statix = pkgs.stdenvNoCC.mkDerivation {
          name = "statix-check";
          src = self;
          nativeBuildInputs = [ statix' ];
          buildPhase = "statix check .";
          installPhase = "touch $out";
        };
      };
    };
}
