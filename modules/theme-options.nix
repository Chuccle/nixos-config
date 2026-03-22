{ lib, ... }:

let
  inherit (lib) mkOption types;

  colorType = types.strMatching "[0-9a-fA-F]{6}";

  fontType = types.submodule {
    options = {
      name = mkOption { type = types.str; };
      size = mkOption { type = types.ints.positive; };
    };
  };

  paletteType = types.submodule {
    options = {
      black = mkOption { type = colorType; };
      red = mkOption { type = colorType; };
      green = mkOption { type = colorType; };
      yellow = mkOption { type = colorType; };
      blue = mkOption { type = colorType; };
      magenta = mkOption { type = colorType; };
      cyan = mkOption { type = colorType; };
      white = mkOption { type = colorType; };
    };
  };

in
{
  options.theme = {

    meta = {
      name = mkOption {
        type = types.str;
        description = "Human-readable theme identifier.";
      };

      colorScheme = mkOption {
        type = types.nullOr types.str;
        default = null;
        description = "Plasma color scheme name — must match an installed .colors file stem.";
      };
    };

    colors = {
      background = mkOption {
        type = types.str;
        description = "Hex with leading #.";
      };
      foreground = mkOption { type = types.str; };
      accent = mkOption { type = types.str; };
      border = mkOption { type = types.str; };
      surface = mkOption { type = types.str; };
    };

    fonts = {
      sans = mkOption { type = fontType; };
      monospace = mkOption { type = fontType; };
      packages = mkOption {
        type = types.listOf types.package;
        default = [ ];
        description = "Font packages to install.";
      };
    };

    gtk = {
      themeName = mkOption { type = types.str; };
      themePackage = mkOption {
        type = types.nullOr types.package;
        default = null;
      };
      icons = mkOption { type = types.str; };
      iconsPackage = mkOption {
        type = types.nullOr types.package;
        default = null;
      };
      cursor = mkOption { type = types.str; };
      cursorPackage = mkOption {
        type = types.nullOr types.package;
        default = null;
      };
      cursorSize = mkOption {
        type = types.ints.positive;
        default = 24;
      };
    };

    qt = {
      style = mkOption { type = types.str; };
      stylePackage = mkOption {
        type = types.nullOr types.package;
        default = null;
      };
    };

    terminal = {
      background = mkOption { type = colorType; };
      foreground = mkOption { type = colorType; };
      alpha = mkOption {
        type = types.str;
        default = "1.0";
      };
      regular = mkOption { type = paletteType; };
      bright = mkOption { type = paletteType; };
    };

    compositor = {
      niri = mkOption {
        type = types.nullOr types.path;
        default = null;
        description = "Path to a niri config.kdl, or null if the theme does not target niri.";
      };
      kwin = mkOption {
        type = types.nullOr types.attrs;
        default = null;
        description = "Attrset consumed by plasma-manager kwin options, or null.";
      };
      pantheon = mkOption {
        type = types.nullOr types.attrs;
        default = null;
        description = "Attrset consumed by Pantheon/elementary options, or null.";
      };
    };

    wallpaper = {
      color = mkOption {
        type = types.nullOr types.str;
        default = null;
        description = "Solid colour fallback (hex with #). Used by swaybg on niri.";
      };
      path = mkOption {
        type = types.nullOr types.path;
        default = null;
        description = "Path to a wallpaper image, or null.";
      };
    };

    launcher = {
      command = mkOption {
        type = types.str;
        default = "fuzzel";
        description = "Command to spawn the app launcher.";
      };

      border = {
        width = mkOption {
          type = types.ints.unsigned;
          default = 1;
        };
        radius = mkOption {
          type = types.ints.unsigned;
          default = 4;
        };
      };
    };
  };
}
