{
  inputs,
  config,
  pkgs,
  lib,
  ...
}:

let
  t = config.theme;
  kw = t.compositor.kwin;

in
{
  services.desktopManager.plasma6.enable = true;

  services.displayManager.sddm = {
    enable = true;
    wayland.enable = true;
  };

  hardware.graphics.enable = true;

  xdg.portal = {
    enable = true;
    extraPortals = [ pkgs.kdePackages.xdg-desktop-portal-kde ];
    config.common.default = "kde";
  };

  home-manager.sharedModules = [
    inputs.plasma-manager.homeModules.plasma-manager
    {
      programs.plasma = {
        enable = true;

        fonts = {
          general = {
            family = t.fonts.sans.name;
            pointSize = t.fonts.sans.size;
          };
          fixedWidth = {
            family = t.fonts.monospace.name;
            pointSize = t.fonts.monospace.size;
          };
          small = {
            family = t.fonts.sans.name;
            pointSize = t.fonts.sans.size - 1;
          };
          toolbar = {
            family = t.fonts.sans.name;
            pointSize = t.fonts.sans.size;
          };
          menu = {
            family = t.fonts.sans.name;
            pointSize = t.fonts.sans.size;
          };
          windowTitle = {
            family = t.fonts.sans.name;
            pointSize = t.fonts.sans.size;
          };
        };

        workspace = {
          colorScheme = lib.mkIf (t.meta.colorScheme != null) t.meta.colorScheme;
          cursor.theme = t.gtk.cursor;
          cursor.size = t.gtk.cursorSize;

          wallpaper = lib.mkIf (t.wallpaper.path != null) (toString t.wallpaper.path);
        };

        kwin = lib.mkIf (kw != null) kw;
      };
    }
  ];

  programs.dconf.enable = true;

  environment.systemPackages =
    with pkgs;
    [
      kdePackages.plasma-integration
      kdePackages.kde-gtk-config
    ]
    ++ lib.optionals (t.gtk.themePackage != null) [ t.gtk.themePackage ]
    ++ lib.optionals (t.gtk.iconsPackage != null) [ t.gtk.iconsPackage ]
    ++ lib.optionals (t.gtk.cursorPackage != null) [ t.gtk.cursorPackage ];
}
