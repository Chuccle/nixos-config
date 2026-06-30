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
        blur.opacity = "0.6";
      };
    };
}
