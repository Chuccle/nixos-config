{
  desktopModules.theme-win95 =
    { pkgs, ... }:
    {
      # WIN95 (retro, flat, hard bevels)
      # Teal desktop, silver 3D chrome, navy selection. Chicago95 (nixpkgs)
      # supplies the GTK theme, icons and VGA font; it ships no cursors, so the
      # classic DMZ X11 cursors stand in. Composed by a host to override the
      # default theme.
      config.theme = {
        name = "win95";

        cornerRadius = 0;
        borderWidth = 2;

        margin = 0;
        padding = 4;

        font.size.normal = 14;
        font.size.big = 18;

        font.sans.name = "Sans";
        font.sans.package = pkgs.chicago95;

        font.mono.name = "JetBrainsMono Nerd Font";
        font.mono.package = pkgs.nerd-fonts.jetbrains-mono;

        icons.name = "Chicago95";
        icons.package = pkgs.chicago95;

        gtk.name = "Chicago95";
        gtk.package = pkgs.chicago95;

        cursor.name = "Vanilla-DMZ";
        cursor.package = pkgs.vanilla-dmz;

        palette = {
          base = "#008080";
          surface = "#c0c0c0";
          overlay = "#dfdfdf";
          muted = "#808080";

          text = "#000000";
          subtext = "#404040";

          accent = "#000080";
          accentText = "#ffffff";

          red = "#800000";
          green = "#008000";
          yellow = "#808000";
          blue = "#000080";

          # The outer half of every bevel. Win95 chrome is four tones deep —
          # white and black on the outside, #dfdfdf and #808080 (`overlay` and
          # `muted`) on the inside — and dropping the outer pair is what makes
          # most recreations read as a grey box with a border.
          edgeLight = "#ffffff";
          edgeShade = "#000000";
        };

        blur.enable = false;
      };
    };
}
