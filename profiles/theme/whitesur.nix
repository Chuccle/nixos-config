{ pkgs, ... }:
{

  theme = {
    meta = {
      name = "whitesur";
      colorScheme = "BreezeDark";
    };

    colors = {
      background = "#f6f6f8";
      foreground = "#1c1c1e";
      accent = "#0071e3";
      border = "#00000012";
      surface = "#ffffff";
    };

    fonts = {
      sans = {
        name = "Geist";
        size = 11;
      };
      monospace = {
        name = "Geist Mono";
        size = 11;
      };
      packages = with pkgs; [
        geist-font
        fira-code
        cantarell-fonts
        font-awesome
      ];
    };

    gtk = {
      themeName = "WhiteSur-Light";
      themePackage = pkgs.whitesur-gtk-theme;

      icons = "WhiteSur";
      iconsPackage = pkgs.whitesur-icon-theme;

      cursor = "Bibata-Modern-Classic";
      cursorPackage = pkgs.bibata-cursors;
      cursorSize = 28;
    };

    qt = {
      style = "adwaita";
      stylePackage = pkgs.adwaita-qt;
    };

    terminal = {
      background = "f6f6f8";
      foreground = "1c1c1e";
      alpha = "0.88";

      regular = {
        black = "1c1c1e";
        red = "ff3b30";
        green = "34c759";
        yellow = "ff9500";
        blue = "0071e3";
        magenta = "af52de";
        cyan = "32ade6";
        white = "f2f2f7";
      };
      bright = {
        black = "636366";
        red = "ff6961";
        green = "30d158";
        yellow = "ffd60a";
        blue = "409cff";
        magenta = "da8fff";
        cyan = "5ac8f5";
        white = "ffffff";
      };
    };

    compositor = {
      niri = ../../niri/whitesur.kdl;
      kwin = {
        effects = {
          desktopSwitching.animation = "slide";
          minimization.animation = "squash";
          windowOpenClose.animation = "glide";
          blur = {
            enable = true;
            strength = 12;
            noiseStrength = 2;
          };
        };
      };
      pantheon = null;
    };

    wallpaper = {
      color = "#d4e5f7";
      path = null;
    };

    launcher.border = {
      width = 1;
      radius = 12;
    };
  };
}
