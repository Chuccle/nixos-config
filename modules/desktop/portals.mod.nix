{
  flake.nixosModules.desktop-portals =
    { lib, pkgs, ... }:
    let
      inherit (lib.lists) singleton;
      inherit (lib.modules) mkForce;
    in
    {
      config.xdg.portal = {
        extraPortals = singleton pkgs.kdePackages.xdg-desktop-portal-kde;

        config.niri."org.freedesktop.impl.portal.FileChooser" = mkForce <| singleton "kde";
      };
    };
}
