{
  perSystem =
    { config, pkgs, ... }:
    {
      devShells.default = pkgs.mkShell {
        packages = [
          config.dev.treefmt.config.build.wrapper
          pkgs.deadnix
          pkgs.direnv
          pkgs.nil
          pkgs.nix-direnv
          pkgs.nixfmt
          pkgs.statix
        ];
      };
    };
}
