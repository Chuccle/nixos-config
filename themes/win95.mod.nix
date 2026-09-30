{
  desktopModules.theme-win95 =
    { lib, pkgs, ... }:
    let
      inherit (lib.modules) mkDefault;
    in
    {
      config.theme = {
        name = "win95";

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

          edgeLight = "#ffffff";
          edgeShade = "#000000";
        };

        blur.enable = false;
      };
    };
}
