# profiles/theme/liquid-glass.nix
#
# Liquid glass theme module.
# Sets config.theme.* — consumed by DE profiles and home.nix.

{ pkgs, ... }:
{

  theme = {
    meta.name = "liquid-glass";

    colors = {
      background = "#050510";
      foreground = "#e2e8f0";
      accent = "#7fc8ff";
      border = "#ffffff18";
      surface = "#0f0f23";
    };

    fonts = {
      sans = {
        name = "Cantarell";
        size = 11;
      };
      monospace = {
        name = "Fira Code";
        size = 11;
      };
      packages = with pkgs; [
        cantarell-fonts
        fira-code
        geist-font
      ];
    };

    gtk = {
      themeName = "adw-gtk3-dark";
      themePackage = pkgs.adw-gtk3;
      icons = "Papirus-Dark";
      iconsPackage = pkgs.papirus-icon-theme;
      cursor = "Bibata-Modern-Ice";
      cursorPackage = pkgs.bibata-cursors;
      cursorSize = 24;
    };

    qt = {
      style = "adwaita-dark";
      stylePackage = pkgs.adwaita-qt;
    };

    terminal = {
      background = "050510";
      foreground = "e2e8f0";
      alpha = "0.82";
      regular = {
        black = "1e1e2e";
        red = "f87171";
        green = "34d399";
        yellow = "fde68a";
        blue = "7fc8ff";
        magenta = "c4b5fd";
        cyan = "5ee7ff";
        white = "cbd5e1";
      };
      bright = {
        black = "475569";
        red = "fca5a5";
        green = "6ee7b7";
        yellow = "fef08a";
        blue = "bae6fd";
        magenta = "ddd6fe";
        cyan = "a5f3fc";
        white = "f1f5f9";
      };
    };

    compositor = {
      # niri: fluid springs, wide gaps, centred columns
      niri = ../../niri/liquid-glass.kdl;
      # kwin: slow fade, rounded corners via Breeze
      kwin = {
        effects = {
          desktopSwitching.animation = "slide";
          minimization.animation = "magiclamp";
          windowOpenClose.animation = "fade";
        };
      };
      pantheon = null;
    };

    wallpaper = {
      color = "#050510";
      path = null;
    };

    launcher.border = {
      width = 1;
      radius = 8;
    };
  };
}
