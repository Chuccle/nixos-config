{ inputs, ... }:
{
  flake.homeModules.home =
    { config, lib, ... }:
    let
      inherit (lib.lists) singleton;
      inherit (lib.modules) mkAliasOptionModule;
    in
    {
      imports = singleton <| mkAliasOptionModule [ "programs" ] [ "rum" "programs" ];

      # XDG
      environment.sessionVariables = {
        XDG_CACHE_HOME = "${config.directory}/.cache";
        XDG_CONFIG_HOME = "${config.directory}/.config";
        XDG_DATA_HOME = "${config.directory}/.local/share";
        XDG_STATE_HOME = "${config.directory}/.local/state";
      };
    };

  flake.nixosModules.home =
    { lib, ... }:
    let
      inherit (lib.lists) singleton;
      inherit (lib.modules) mkAliasOptionModule;
    in
    {
      imports = [
        inputs.hjem.nixosModules.hjem
        (mkAliasOptionModule [ "home" ] [ "hjem" ])
      ];

      home.extraModules = singleton inputs.hjem-rum.hjemModules.hjem-rum;

      home.clobberByDefault = true;
      home.users.root = { };
    };
}
