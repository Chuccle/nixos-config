{
  desktopModules.theme-win95 =
    { lib, pkgs, ... }:
    let
      inherit (lib.modules) mkDefault;
    in
    {
      # WIN95 (retro, flat, hard bevels)
      # Teal desktop, silver 3D chrome, navy selection. Chicago95 (nixpkgs)
      # supplies the GTK theme, icons and VGA font; it ships no cursors, so the
      # classic DMZ X11 cursors stand in. Composed by a host to override the
      # default theme.
      config.theme = {
        name = "win95";

        # Silver chrome and black text: light, whatever the era. Without this
        # every GTK app in the session would be asked to prefer its dark
        # variant and render dark widgets inside Chicago95's light frames.
        #
        # `mkDefault` even though there is nothing to switch to, so a host that
        # asks for dark anyway gets told which theme has no dark palette rather
        # than a conflicting-definition error naming neither.
        appearance = mkDefault "light";

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

        # One palette, because Win95 had one: there is no dark mode to toggle
        # into, and inventing one would be a different theme.
        palettes.light = {
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
