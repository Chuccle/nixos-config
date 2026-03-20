# profiles/de/plasma.nix
#
# KDE Plasma 6 DE profile.
# Enables SDDM, Plasma, and wires theme.* into plasma-manager where possible.
# theme.compositor.kwin can carry kwin rule attrsets set by the theme module.

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
  # ── Plasma + SDDM ────────────────────────────────────────────────────────────
  services.desktopManager.plasma6.enable = true;

  services.displayManager.sddm = {
    enable = true;
    wayland.enable = true;
  };

  # ── Graphics ────────────────────────────────────────────────────────────────
  hardware.graphics.enable = true;

  # ── XDG portal — Plasma provides its own ────────────────────────────────────
  xdg.portal = {
    enable = true;
    extraPortals = [ pkgs.kdePackages.xdg-desktop-portal-kde ];
    config.common.default = "kde";
  };

  # ── plasma-manager via home-manager ─────────────────────────────────────────
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
          colorScheme = t.meta.name;
          cursor.theme = t.gtk.cursor;
          cursor.size = t.gtk.cursorSize;

          # Solid colour wallpaper — Plasma can do more but this is the
          # theme-agnostic baseline. Override per-theme in compositor.kwin
          # or extend this block in a theme-specific overlay module.
          wallpaper = lib.mkIf (t.wallpaper.path != null) (toString t.wallpaper.path);
        };

        # kwin window rules supplied by the theme, if any
        kwin = lib.mkIf (kw != null) kw;
      };
    }
  ];

  # ── GTK integration inside Plasma ───────────────────────────────────────────
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
