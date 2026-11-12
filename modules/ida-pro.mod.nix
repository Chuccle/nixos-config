{ self, ... }:
{
  flake.homeModules.ida-pro =
    { lib, pkgs, ... }:
    let
      inherit (lib.lists) singleton;
      ida = self.packages.${pkgs.stdenv.hostPlatform.system};
    in
    {
      packages = singleton ida.ida-pro;

      files.".idapro/themes/default/theme.css".source = "${ida.ida-pro-theme}/theme.css";
    };
}
