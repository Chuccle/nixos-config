{
  flake.homeModules.difftastic =
    { lib, pkgs, ... }:
    let
      inherit (lib.lists) singleton;
      inherit (lib.meta) getExe;

      difft = pkgs.writeShellScriptBin "difft" /* bash */ ''
        exec ${getExe pkgs.difftastic} --background "dark" "$@"
      '';
    in
    {
      packages = singleton difft;

      # GIT INTEGRATION
      # The file generator (toGitINI) is owned by the version-control `git`
      # module; this module only contributes diff settings, which merge in.
      xdg.config.files."git/config".value = {
        diff.external = getExe difft;
        diff.tool = "difftastic";
        difftool.difftastic.cmd = /* sh */ ''${getExe difft} "$LOCAL" "$REMOTE"'';
      };

      # JUJUTSU INTEGRATION
      # The file generator (writeTOML) is owned by the version-control `jujutsu`
      # module; this module only contributes the diff-formatter.
      xdg.config.files."jj/config.toml".value.ui.diff-formatter = [
        (getExe difft)
        "--color"
        "always"
        "$left"
        "$right"
      ];
    };
}
