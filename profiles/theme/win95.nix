{ pkgs, ... }:
{

  theme = {
    meta = {
      name = "win95";
      colorScheme = null;
    };

    colors = {
      background = "#008080";
      foreground = "#ffffff";
      accent = "#000080";
      border = "#c0c0c0";
      surface = "#c0c0c0";
    };

    fonts = {
      sans = {
        name = "Liberation Sans";
        size = 9;
      };
      monospace = {
        name = "Terminus";
        size = 10;
      };
      packages = with pkgs; [
        liberation_ttf
        terminus_font
      ];
    };

    gtk = {
      themeName = "Chicago95";
      themePackage = pkgs.chicago95;
      icons = "Chicago95";
      iconsPackage = pkgs.chicago95;
      cursor = "Chicago95_Cursor_Black";
      cursorPackage = pkgs.chicago95;
      cursorSize = 16;
    };

    qt = {
      style = "gtk2";
      stylePackage = pkgs.libsForQt5.qtstyleplugins;
    };

    terminal = {
      background = "1c1c1c";
      foreground = "c0c0c0";
      alpha = "1.0";
      regular = {
        black = "000000";
        red = "800000";
        green = "008000";
        yellow = "808000";
        blue = "000080";
        magenta = "800080";
        cyan = "008080";
        white = "c0c0c0";
      };
      bright = {
        black = "808080";
        red = "ff0000";
        green = "00ff00";
        yellow = "ffff00";
        blue = "0000ff";
        magenta = "ff00ff";
        cyan = "00ffff";
        white = "ffffff";
      };
    };

    compositor = {
      niri = ../../niri/win95.kdl;
      kwin = {
        effects = {
          desktopSwitching.animation = "off";
          minimization.animation = "off";
          windowOpenClose.animation = "off";
        };
      };
      pantheon = null;
    };

    wallpaper = {
      color = "#008080";
      path = null;
    };

    launcher.border = {
      width = 2;
      radius = 0;
    };
  };
}
