{
  flake.nixosModules.desktop =
    { lib, ... }:
    let
      inherit (lib.options) mkOption;
      inherit (lib.types) nullOr str;
    in
    {
      # DESKTOP DATA
      # Pure data a composed compositor publishes and the login module consumes.
      # There is no session *selector* — the host composes the stack it wants.
      options.desktop.sessionCommand = mkOption {
        type = str;
        default = "";
        description = "Command the login manager execs to start the composed session.";
      };

      options.desktop.autoLoginUser = mkOption {
        type = nullOr str;
        default = null;
        description = "User to auto-login into the session, if any.";
      };
    };
}
