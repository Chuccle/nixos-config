{
  flake.nixosModules.shell =
    {
      config,
      lib,
      pkgs,
      ...
    }:
    let
      inherit (lib.modules) mkIf;
      inherit (lib.options) mkOption;
      inherit (lib.types) enum nullOr;

      cfg = config.shell;

      shellPkg =
        {
          inherit (pkgs) nushell;
          inherit (pkgs) bash;
          inherit (pkgs) zsh;
        }
        .${cfg.default};
    in
    {
      options.shell.default = mkOption {
        type = nullOr (enum [
          "nushell"
          "bash"
          "zsh"
        ]);
        default = null;
        description = ''
          Default login shell for all users.

            "nushell" — Nu shell (structured data, modern feel)
            "bash"    — GNU Bash (ubiquitous, POSIX)
            "zsh"     — Z shell (interactive-friendly)

          null → no default shell set; inherit system default.
        '';
        example = "nushell";
      };

      config = mkIf (cfg.default != null) {
        environment.shells = [ shellPkg ];

        users.defaultUserShell = shellPkg;

        programs.zsh.enable = mkIf (cfg.default == "zsh") true;
      };
    };
}
