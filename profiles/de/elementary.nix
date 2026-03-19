{
  config,
  pkgs,
  lib,
  ...
}:

let
  t = config.theme;

in
{
  services = {
    desktopManager.pantheon.enable = true;
    xserver = {
      enable = true;
      displayManager.lightdm = {
        enable = true;
        greeters.pantheon.enable = true;
      };
    };
  };

  hardware.graphics.enable = true;

  xdg.portal = {
    enable = true;
    extraPortals = [ pkgs.pantheon.xdg-desktop-portal-pantheon ];
    config.common.default = "pantheon";
  };

  programs.dconf.enable = true;

  theme.launcher.command = "slingshot-launcher";

  home-manager.sharedModules = [
    {
      dconf.settings = {
        "org/gnome/desktop/interface" = {
          gtk-theme = t.gtk.themeName;
          icon-theme = t.gtk.icons;
          cursor-theme = t.gtk.cursor;
          cursor-size = t.gtk.cursorSize;
          font-name = "${t.fonts.sans.name} ${toString t.fonts.sans.size}";
          monospace-font-name = "${t.fonts.monospace.name} ${toString t.fonts.monospace.size}";
        };
      };

      gtk = {
        enable = true;
        theme = lib.mkIf (t.gtk.themePackage != null) {
          name = t.gtk.themeName;
          package = t.gtk.themePackage;
        };
        iconTheme = lib.mkIf (t.gtk.iconsPackage != null) {
          name = t.gtk.icons;
          package = t.gtk.iconsPackage;
        };
        cursorTheme = lib.mkIf (t.gtk.cursorPackage != null) {
          name = t.gtk.cursor;
          package = t.gtk.cursorPackage;
          size = t.gtk.cursorSize;
        };
        font = { inherit (t.fonts.sans) name size; };
      };
    }
  ];

  environment.systemPackages =
    lib.optionals (t.gtk.themePackage != null) [ t.gtk.themePackage ]
    ++ lib.optionals (t.gtk.iconsPackage != null) [ t.gtk.iconsPackage ]
    ++ lib.optionals (t.gtk.cursorPackage != null) [ t.gtk.cursorPackage ];
}
