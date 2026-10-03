{
  flake.homeModules.use-xdg-dirs =
    { config, lib, ... }:
    let
      inherit (lib.generators) mkKeyValueDefault toKeyValue;
    in
    {
      xdg.data.files."android".type = "directory";
      environment.sessionVariables.ANDROID_USER_HOME = "${config.xdg.data.directory}/android";
      programs.nushell.extraConfig = /* nu */ ''
        def --wrapped adb [...args] {
          with-env { HOME: "${config.xdg.data.directory}/android" } { ^adb ...$args }
        }
      '';

      xdg.config.files."aws".type = "directory";
      environment.sessionVariables.AWS_CONFIG_FILE = "${config.xdg.config.directory}/aws/config";
      environment.sessionVariables.AWS_SHARED_CREDENTIALS_FILE = "${config.xdg.config.directory}/aws/credentials";

      files.".ssh/config".text = toKeyValue { mkKeyValue = mkKeyValueDefault { } " "; } {
        Include = "${config.xdg.config.directory}/ssh/config";
      };

      xdg.cache.files."zsh".type = "directory";
      environment.sessionVariables.ZDOTDIR = "${config.xdg.config.directory}/zsh";

      xdg.data.files."cargo".type = "directory";
      environment.sessionVariables.CARGO_HOME = "${config.xdg.data.directory}/cargo";

      xdg.data.files."go".type = "directory";
      environment.sessionVariables.GOPATH = "${config.xdg.data.directory}/go";

      xdg.config.files."ripgrep".type = "directory";
      environment.sessionVariables.RIPGREP_CONFIG_PATH = "${config.xdg.config.directory}/ripgrep/config";

      xdg.state.files."sqlite".type = "directory";
      environment.sessionVariables.SQLITE_HISTORY = "${config.xdg.state.directory}/sqlite/history";

      xdg.state.files."zsh".type = "directory";
      environment.sessionVariables.HISTFILE = "${config.xdg.state.directory}/zsh/history";

      xdg.state.files."less".type = "directory";
      environment.sessionVariables.LESSHISTFILE = "${config.xdg.state.directory}/less/history";

      xdg.state.files."node".type = "directory";
      environment.sessionVariables.NODE_REPL_HISTORY = "${config.xdg.state.directory}/node/history";

      xdg.state.files."python".type = "directory";
      environment.sessionVariables.PYTHON_HISTORY = "${config.xdg.state.directory}/python/history";
    };
}
