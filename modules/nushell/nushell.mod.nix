{
  flake.nixosModules.nushell =
    { config, lib, ... }:
    let
      inherit (lib.modules) mkIf;

      cfg = config.shell;
    in
    {
      config = mkIf (cfg.default == "nushell") {
        programs.nushell.enable = true;
      };
    };
}
