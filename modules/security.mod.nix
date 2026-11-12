{
  flake.nixosModules.security =
    { config, lib, ... }:
    let
      inherit (lib.attrsets) attrValues;
      inherit (lib.lists) filter map singleton;
    in
    {
      security = {
        doas.enable = true;
        sudo.enable = false;
        doas.extraRules =
          config.users.users
          |> attrValues
          |> filter ({ isNormalUser, ... }: isNormalUser)
          |> map (
            { name, ... }: {
              users = singleton name;
              keepEnv = true;
              persist = true;
            }
          );
      };
    };
}
