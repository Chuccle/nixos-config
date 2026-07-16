{
  desktopModules.theme-tahoe =
    { pkgs, ... }:
    {
      # TAHOE (liquid glass)
      # Translucent dark surfaces, generous radius, blur on. Composed by a host
      # to override the default theme.
      config.theme = {
        name = "tahoe";

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

        icons.name = "WhiteSur-dark";
        icons.package = pkgs.whitesur-icon-theme;

        gtk.name = "WhiteSur-Dark";
        gtk.package = pkgs.whitesur-gtk-theme;

        cursor.name = "WhiteSur-cursors";
        cursor.package = pkgs.whitesur-cursors;

        # WALLPAPER
        # Generated at build time (nothing fetched, nothing to hash): a soft
        # blue radial wash in the macOS-Tahoe spirit, light center falling off
        # to deep blue, for the glass surfaces to pick up.
        wallpaper = pkgs.runCommand "tahoe-wallpaper.png" { nativeBuildInputs = [ pkgs.imagemagick ]; } ''
          magick -size 3840x2160 radial-gradient:"#a8d0f0"-"#16406e" \
            -attenuate 0.25 +noise Gaussian -blur 0x2 PNG24:$out
        '';

        palette = {
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
        };

        blur.enable = true;
        blur.radius = 32;
        blur.opacity = 0.6;
      };
    };
}
