{
  flake.nixosModules.security =
    { config, lib, ... }:
    let
      inherit (lib.attrsets) attrValues;
      inherit (lib.lists) filter singleton;
    in
    {
      security = {
        doas.enable = true;
        sudo.enable = false;
        doas.extraRules = map (user: {
          users = singleton user.name;
          keepEnv = true;
          persist = true;
        }) (filter (u: u.isNormalUser) (attrValues config.users.users));
      };
    };
}
