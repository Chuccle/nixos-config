{
  flake.nixosModules.security =
    { config, lib, ... }:
    let
      inherit (lib.lists) singleton;
      inherit (lib.attrsets) attrValues;
    in
    {
      security = {
        doas.enable = true;
        sudo.enable = false;
        doas.extraRules = map (user: {
          users = singleton user.name;
          keepEnv = true;
          persist = true;
        }) (attrValues config.users.users);
      };
    };
}
