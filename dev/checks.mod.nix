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
              "*.json"
              "*.md"
            ];
          };
          statix = {
            enable = true;
            package = statix';
          };
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
          statix'
          pkgs.deadnix
          pkgs.direnv
          pkgs.nil
          pkgs.nix-direnv
          pkgs.nixfmt
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
          { stdenvNoCC }:
          stdenvNoCC.mkDerivation {
            name = "statix-check";
            src = self;
            nativeBuildInputs = singleton statix';
            buildPhase = "statix check .";
            installPhase = "touch $out";
          }
        ) { };
      }
      // hostChecks;
    };
}
