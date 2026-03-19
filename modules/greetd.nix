{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.greetd;

  tuigreetPkg = pkgs.tuigreet;

  tuigreetArgs = lib.flatten [
    "--time"
    [
      "--time-format"
      cfg.tuigreet.timeFormat
    ]
    [
      "--greeting"
      cfg.tuigreet.greeting
    ]
    [
      "--cmd"
      cfg.session.command
    ]
    [
      "--width"
      (toString cfg.tuigreet.width)
    ]
    (lib.optional cfg.tuigreet.asterisks "--asterisks")
    (lib.optional cfg.tuigreet.remember "--remember")
    (lib.optional cfg.tuigreet.rememberSession "--remember-user-session")
  ];

  tuigreetCmd = lib.escapeShellArgs ([ "${tuigreetPkg}/bin/tuigreet" ] ++ tuigreetArgs);

in
{
  options.greetd = {
    enable = lib.mkEnableOption "greetd with tuigreet";

    session = {
      command = lib.mkOption {
        type = lib.types.str;
        description = "Full path to the session binary.";
        example = "\${pkgs.niri}/bin/niri-session";
      };
      name = lib.mkOption {
        type = lib.types.str;
        default = "default";
      };
    };

    tuigreet = {
      greeting = lib.mkOption {
        type = lib.types.str;
        default = "Welcome";
      };
      timeFormat = lib.mkOption {
        type = lib.types.str;
        default = "%A %d %B %Y   %H:%M";
      };
      width = lib.mkOption {
        type = lib.types.ints.positive;
        default = 48;
      };
      asterisks = lib.mkOption {
        type = lib.types.bool;
        default = true;
      };
      remember = lib.mkOption {
        type = lib.types.bool;
        default = true;
      };
      rememberSession = lib.mkOption {
        type = lib.types.bool;
        default = true;
      };
    };
  };

  config = lib.mkIf cfg.enable {
    services.greetd = {
      enable = true;
      settings.default_session = {
        command = tuigreetCmd;
        user = "greeter";
      };
    };

    users.groups.greeter = { };
  };
}
