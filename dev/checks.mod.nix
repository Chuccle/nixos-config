{ self, ... }:
{
  perSystem =
    {
      config,
      lib,
      pkgs,
      ...
    }:
    let
      inherit (lib.lists) singleton;
      treefmt = config.dev.treefmt;

      statixConfig = pkgs.linkFarm "statix-config" {
        "statix.toml" = (pkgs.formats.toml { }).generate "statix.toml" {
          disabled = treefmt.config.programs.statix.disabled-lints;
        };
      };

      lintCheck =
        name: package: command:
        pkgs.stdenvNoCC.mkDerivation {
          name = "${name}-check";
          src = self;
          nativeBuildInputs = singleton package;
          buildPhase = command;
          installPhase = "touch $out";
        };
    in
    {
      checks = {
        formatting = treefmt.config.build.check self;
        deadnix = lintCheck "deadnix" pkgs.deadnix "deadnix --fail .";
        actionlint = lintCheck "actionlint" pkgs.actionlint "actionlint .github/workflows/*.yml";
        statix = lintCheck "statix" pkgs.statix "statix check --config ${statixConfig}/statix.toml .";
      };
    };
}
