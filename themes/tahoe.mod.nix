{
  desktopModules.theme-tahoe =
    {
      config,
      lib,
      pkgs,
      ...
    }:
    let
      inherit (lib.modules) mkDefault;

      light = config.theme.appearance == "light";

      wallpaperSource = if light then ./tahoe/wallpaper-light.svg else ./tahoe/wallpaper-dark.svg;
    in
    {
      config.theme = {
        name = "tahoe";

        appearance = mkDefault "light";

        cornerRadius = 20;
        borderWidth = 1;

        margin = 8;
        padding = 12;

        font.size.normal = 16;
        font.size.big = 22;

        font.sans.name = "Inter";
        font.sans.package = pkgs.inter;

        font.mono.name = "JetBrainsMono Nerd Font";
        font.mono.package = pkgs.nerd-fonts.jetbrains-mono;

        icons.name = if light then "WhiteSur-light" else "WhiteSur-dark";
        icons.package = pkgs.whitesur-icon-theme;

        gtk.name = if light then "WhiteSur-Light" else "WhiteSur-Dark";
        gtk.package = pkgs.whitesur-gtk-theme;

        cursor.name = "WhiteSur-cursors";
        cursor.package = pkgs.whitesur-cursors;

        # WALLPAPER
        wallpaper =
          pkgs.runCommand "tahoe-wallpaper-${config.theme.appearance}.png"
            {
              nativeBuildInputs = [
                pkgs.libxml2
                pkgs.resvg
              ];
            }
            /* bash */ ''
              xmllint --noout ${wallpaperSource}
              resvg --width 3840 --height 2160 ${wallpaperSource} $out
            '';

        # SYSTEM COLOURS
        palettes.light = {
          base = "#e9e9ec";
          surface = "#f7f7fa";
          overlay = "#ffffff";
          muted = "#8e8e93";

          text = "#1c1c1e";
          subtext = "#3c3c43";

          accent = "#007aff";
          accentText = "#ffffff";

          red = "#ff3b30";
          green = "#34c759";
          yellow = "#ffcc00";
          blue = "#007aff";

          edgeLight = "#ffffff";
          edgeShade = "#000000";
        };

        palettes.dark = {
          base = "#1e1e1e";
          surface = "#2c2c2e";
          overlay = "#3a3a3c";
          muted = "#8e8e93";

          text = "#ffffff";
          subtext = "#ebebf5";

          accent = "#0a84ff";
          accentText = "#ffffff";

          red = "#ff453a";
          green = "#32d74b";
          yellow = "#ffd60a";
          blue = "#0a84ff";

          edgeLight = "#ffffff";
          edgeShade = "#000000";
        };

        blur.enable = true;
        blur.radius = 32;
        blur.opacity = 0.3;
      };
    };
}
