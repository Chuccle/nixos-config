{
  flake.nixosModules.shell =
    {
      config,
      lib,
      pkgs,
      ...
    }:
    let
      inherit (lib.lists) singleton;
      inherit (lib.options) mkOption;
      inherit (lib.types) enum;

      shellPkg =
        {
          inherit (pkgs) nushell bash zsh;
        }
        .${config.shell.default};
    in
    {
      options.shell.default = mkOption {
        type = enum [
          "nushell"
          "bash"
          "zsh"
        ];
        description = "Default login shell for all users.";
        example = "nushell";
      };

      config = {
        environment.shells = singleton shellPkg;
        users.defaultUserShell = shellPkg;

        programs.zsh.enable = config.shell.default == "zsh";
      };
    };
}
