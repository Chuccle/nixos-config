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
    in
    {
      # TAHOE (liquid glass)
      # Translucent surfaces, generous radius, blur on. Composed by a host to
      # override the default theme.
      config.theme = {
        name = "tahoe";

        # Stock Tahoe is a light desktop: near-white chrome, black text, the
        # light-mode system accent. `mkDefault` rather than a plain value so a
        # host can pick the dark end of the same design with one line —
        # `theme.appearance = "dark";` — and every adapter follows.
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
        # Authored as SVG in ./tahoe/wallpaper.svg and rasterised at build
        # time — nothing fetched, nothing to hash. resvg rather than librsvg
        # because the grain layer uses feTurbulence, which librsvg renders
        # inconsistently. xmllint gates the source first, so a malformed
        # gradient fails the build instead of rendering as a black screen.
        wallpaper =
          pkgs.runCommand "tahoe-wallpaper.png"
            {
              nativeBuildInputs = [
                pkgs.libxml2
                pkgs.resvg
              ];
            }
            ''
              xmllint --noout ${./tahoe/wallpaper.svg}
              resvg --width 3840 --height 2160 ${./tahoe/wallpaper.svg} $out
            '';

        # SYSTEM COLOURS
        # Apple's own values for each appearance, not one palette lightened:
        # the system blue really is #007aff in light and #0a84ff in dark, and
        # the greys are the two ends of the same set rather than inversions of
        # each other.
        palette = {
          base = if light then "#e9e9ec" else "#1e1e1e";
          surface = if light then "#f7f7fa" else "#2c2c2e";
          overlay = if light then "#ffffff" else "#3a3a3c";
          muted = "#8e8e93";

          text = if light then "#1c1c1e" else "#ffffff";
          subtext = if light then "#3c3c43" else "#ebebf5";

          accent = if light then "#007aff" else "#0a84ff";
          accentText = "#ffffff";

          red = if light then "#ff3b30" else "#ff453a";
          green = if light then "#34c759" else "#32d74b";
          yellow = if light then "#ffcc00" else "#ffd60a";
          blue = if light then "#007aff" else "#0a84ff";

          # Glass is lit from above: a white specular hairline along the top
          # edge and a black cast shadow underneath. Both are pure rather than
          # tinted from `base` — a shadow the colour of the surface it falls
          # on reads as a grey border instead of depth.
          edgeLight = "#ffffff";
          edgeShade = "#000000";
        };

        blur.enable = true;
        blur.radius = 32;
        blur.opacity = 0.6;
      };
    };
}
