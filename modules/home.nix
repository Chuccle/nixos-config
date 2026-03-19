{ lib, osConfig, ... }:

let
  t = osConfig.theme;
  tf = t.fonts;
  tg = t.gtk;
  tq = t.qt;
  tt = t.terminal;

  toHex = s: lib.removePrefix "#" s;

in
{
  home = {
    stateVersion = "25.11";

    pointerCursor = lib.mkIf (tg.cursorPackage != null) {
      name = tg.cursor;
      package = tg.cursorPackage;
      size = tg.cursorSize;
      gtk.enable = true;
    };

    packages =
      tf.packages
      ++ lib.optionals (tg.themePackage != null) [ tg.themePackage ]
      ++ lib.optionals (tg.iconsPackage != null) [ tg.iconsPackage ]
      ++ lib.optionals (tg.cursorPackage != null) [ tg.cursorPackage ]
      ++ lib.optionals (tq.stylePackage != null) [ tq.stylePackage ];
  };

  gtk = {
    enable = true;
    theme = lib.mkIf (tg.themePackage != null) {
      name = tg.themeName;
      package = lib.mkDefault tg.themePackage;
    };
    iconTheme = lib.mkIf (tg.iconsPackage != null) {
      name = tg.icons;
      package = lib.mkDefault tg.iconsPackage;
    };
    cursorTheme = lib.mkIf (tg.cursorPackage != null) {
      name = tg.cursor;
      package = lib.mkDefault tg.cursorPackage;
      size = tg.cursorSize;
    };
    font = { inherit (tf.sans) name size; };
  };

  qt = {
    enable = true;
    platformTheme.name = "gtk";
    style = lib.mkIf (tq.stylePackage != null) {
      name = tq.style;
      package = tq.stylePackage;
    };
  };

  fonts.fontconfig.enable = true;

  programs = {
    foot = {
      enable = true;
      settings = {
        main = {
          font = "${tf.monospace.name}:size=${toString tf.monospace.size}";
          dpi-aware = "yes";
          pad = "8x8";
        };
        colors-dark = {
          background = toHex tt.background;
          foreground = toHex tt.foreground;
          inherit (tt) alpha;
          regular0 = tt.regular.black;
          regular1 = tt.regular.red;
          regular2 = tt.regular.green;
          regular3 = tt.regular.yellow;
          regular4 = tt.regular.blue;
          regular5 = tt.regular.magenta;
          regular6 = tt.regular.cyan;
          regular7 = tt.regular.white;
          bright0 = tt.bright.black;
          bright1 = tt.bright.red;
          bright2 = tt.bright.green;
          bright3 = tt.bright.yellow;
          bright4 = tt.bright.blue;
          bright5 = tt.bright.magenta;
          bright6 = tt.bright.cyan;
          bright7 = tt.bright.white;
        };
      };
    };
    zoxide = {
      enable = true;
      enableNushellIntegration = true;
    };
    nushell = {
      enable = true;
    };
  };
}
