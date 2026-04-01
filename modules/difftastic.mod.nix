{
  flake.homeModules.difftastic =
    {
      lib,
      pkgs,
      ...
    }:
    let
      inherit (lib.meta) getExe;
      inherit (lib.lists) singleton;

      difft = pkgs.writeShellScriptBin "difft" /* bash */ ''
        exec ${getExe pkgs.difftastic} --background "dark" "$@"
      '';
    in
    {
      packages = singleton difft;

      # GIT INTEGRATION
      # xdg.config.files."git/config".generator = toGitINI; # FIXME
      xdg.config.files."git/config".value = {
        diff.external = getExe difft;
        diff.tool = "difftastic";
        difftool.difftastic.cmd = # sh
          ''${getExe difft} "$LOCAL" "$REMOTE"'';
      };

      # JUJUTSU INTEGRATION
      # xdg.config.files."jj/config.toml".generator = toTOML; # FIXME
      xdg.config.files."jj/config.toml".value.ui.diff-formatter = [
        (getExe difft)
        "--color"
        "always"
        "$left"
        "$right"
      ];
    };
}
