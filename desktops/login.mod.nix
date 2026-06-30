{
  desktopModules.login =
    {
      config,
      lib,
      pkgs,
      ...
    }:
    let
      inherit (lib.meta) getExe;
      inherit (lib.modules) mkIf;
      inherit (lib.strings) escapeShellArg;

      inherit (config.desktop) sessionCommand autoLoginUser;
    in
    {
      # LOGIN
      # Pure: wires greetd to whatever command the composed compositor published.
      services.greetd.enable = true;

      services.greetd.settings.default_session = {
        command = "${getExe pkgs.tuigreet} --time --remember --cmd ${escapeShellArg sessionCommand}";
        user = "greeter";
      };

      # AUTOLOGIN
      # When a host names an autoLoginUser, skip the greeter.
      services.greetd.settings.initial_session = mkIf (autoLoginUser != null) {
        command = sessionCommand;
        user = autoLoginUser;
      };
    };
}
