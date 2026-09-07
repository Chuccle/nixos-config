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
      # TAHOE (liquid glass)
      # Translucent surfaces, generous radius, blur on. Composed by a host to
      # override the default theme.
      config.theme = {
        name = "tahoe";

        # Where the session starts, not where it is stuck: stock Tahoe is a
        # light desktop, and the dark side of the same design is a toggle away
        # at runtime (Control Centre, `dms ipc call theme toggle`, or
        # Mod+Shift+T). This decides what a fresh login shows, and it is what
        # the GTK and Qt theme files below are built against, so a host that
        # lives in dark mode should say `theme.appearance = "dark";` rather
        # than toggling after every login.
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
        # Authored as SVG in ./tahoe/ and rasterised at build time — nothing
        # fetched, nothing to hash. One file per appearance, the same cloth
        # under different light, chosen by the appearance the session starts
        # in: DMS keeps its per-mode wallpapers in session state with no IPC to
        # set them, so this follows the declared side rather than the toggle.
        #
        # resvg rather than librsvg because the grain layer uses feTurbulence,
        # which librsvg renders inconsistently. xmllint gates the source first,
        # so a malformed gradient fails the build instead of rendering as a
        # black screen.
        wallpaper =
          pkgs.runCommand "tahoe-wallpaper-${config.theme.appearance}.png"
            {
              nativeBuildInputs = [
                pkgs.libxml2
                pkgs.resvg
              ];
            }
            ''
              xmllint --noout ${wallpaperSource}
              resvg --width 3840 --height 2160 ${wallpaperSource} $out
            '';

        # SYSTEM COLOURS
        # Apple's own values for each appearance, written out as two palettes
        # rather than one lightened into the other: the system blue really is
        # #007aff in light and #0a84ff in dark, and the greys are the two ends
        # of the same set, not inversions of each other.
        #
        # Both sides are declared, so the desktop can be switched between them
        # while it runs — see `theme.palettes`.
        #
        # Glass is lit from above in either mode: a white specular hairline
        # along the top edge over a black cast shadow. Both stay pure rather
        # than tinted from `base`, because a shadow the colour of the surface
        # it falls on reads as a grey border instead of as depth.
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
        blur.opacity = 0.6;
      };
    };
}
