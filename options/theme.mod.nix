{
  flake.nixosModules.theme =
    { lib, pkgs, ... }:
    let
      inherit (lib.attrsets) genAttrs;
      inherit (lib.lists) foldl';
      inherit (lib.modules) mkDefault;
      inherit (lib.options) mkOption;
      inherit (lib.strings)
        removePrefix
        stringToCharacters
        substring
        toLower
        ;
      inherit (lib.types)
        addCheck
        bool
        enum
        float
        nonEmptyStr
        nullOr
        package
        path
        str
        strMatching
        submodule
        ;
      inherit (lib.types.ints) unsigned;

      hexDigits = {
        "0" = 0;
        "1" = 1;
        "2" = 2;
        "3" = 3;
        "4" = 4;
        "5" = 5;
        "6" = 6;
        "7" = 7;
        "8" = 8;
        "9" = 9;
        "a" = 10;
        "b" = 11;
        "c" = 12;
        "d" = 13;
        "e" = 14;
        "f" = 15;
      };

      # DESIGN TOKENS

      colorNames = [
        "accent"
        "accentText"
        "base"
        "blue"
        "edgeLight"
        "edgeShade"
        "green"
        "muted"
        "overlay"
        "red"
        "subtext"
        "surface"
        "text"
        "yellow"
      ];

      colorOption = mkOption {
        type = strMatching "#[0-9a-fA-F]{6}";
        apply =
          hex:
          let
            bare = removePrefix "#" hex;

            byte =
              offset:
              foldl' (acc: digit: acc * 16 + hexDigits.${digit}) 0 (
                stringToCharacters (toLower (substring offset 2 bare))
              );
          in
          {
            inherit bare hex;

            # qt6ct colour scheme values are #AARRGGBB, alpha first.
            argb = "#ff${bare}";

            # KDE colour schemes take a decimal r,g,b triplet.
            rgb = "${toString (byte 0)},${toString (byte 2)},${toString (byte 4)}";
          };
      };

      colorView = mkOption {
        type = submodule {
          options = {
            argb = mkOption { type = str; };
            bare = mkOption { type = str; };
            hex = mkOption { type = str; };
            rgb = mkOption { type = str; };
          };
        };
      };

      paletteOf = color: submodule { options = genAttrs colorNames (_name: color); };
    in
    {
      options.theme = mkOption {
        description = "Active theme tokens.";
        type = submodule (
          { config, ... }:
          {
            options = {
              name = mkOption {
                type = strMatching "[a-z0-9-]+";
                description = "Identifier of the active theme.";
              };

              # WHICH END OF THE RAMP THE PALETTE SITS AT
              appearance = mkOption {
                type = enum [
                  "dark"
                  "light"
                ];
                default = "dark";
                description = "Whether the palette is a dark or a light one.";
              };

              cornerRadius = mkOption { type = unsigned; };
              borderWidth = mkOption { type = unsigned; };

              margin = mkOption { type = unsigned; };
              padding = mkOption { type = unsigned; };

              font.size.normal = mkOption { type = unsigned; };
              font.size.big = mkOption { type = unsigned; };

              font.sans.name = mkOption { type = nonEmptyStr; };
              font.sans.package = mkOption { type = package; };

              font.mono.name = mkOption { type = nonEmptyStr; };
              font.mono.package = mkOption { type = package; };

              icons.name = mkOption { type = nonEmptyStr; };
              icons.package = mkOption { type = package; };

              gtk.name = mkOption { type = nonEmptyStr; };
              gtk.package = mkOption { type = package; };

              cursor.name = mkOption { type = nonEmptyStr; };
              cursor.package = mkOption { type = package; };
              cursor.size = mkOption {
                type = unsigned;
                default = 24;
              };

              wallpaper = mkOption {
                type = nullOr path;
                default = null;
              };

              # SEMANTIC PALETTE
              palettes.dark = mkOption {
                type = nullOr (paletteOf colorOption);
                default = null;
              };
              palettes.light = mkOption {
                type = nullOr (paletteOf colorOption);
                default = null;
              };

              palette = mkOption {
                type = paletteOf colorView;
                readOnly = true;
                default =
                  let
                    active = config.palettes.${config.appearance};
                  in
                  if active == null then
                    throw "theme \"${config.name}\" has no ${config.appearance} palette: set theme.palettes.${config.appearance}, or point theme.appearance at one it does have"
                  else
                    active;
              };

              # GLASS / BLUR
              blur.enable = mkOption {
                type = bool;
                default = false;
              };
              blur.radius = mkOption {
                type = unsigned;
                default = 0;
              };
              blur.opacity = mkOption {
                type = addCheck float (opacity: opacity >= 0.0 && opacity <= 1.0);
                default = 1.0;
              };
            };
          }
        );
      };

      config.theme = mkDefault {
        name = "gruvbox";

        cornerRadius = 4;
        borderWidth = 2;

        margin = 0;
        padding = 8;

        font.size.normal = 16;
        font.size.big = 20;

        font.sans.name = "Lexend";
        font.sans.package = pkgs.lexend;

        font.mono.name = "JetBrainsMono Nerd Font";
        font.mono.package = pkgs.nerd-fonts.jetbrains-mono;

        icons.name = "Gruvbox-Plus-Dark";
        icons.package = pkgs.gruvbox-plus-icons;

        gtk.name = "Gruvbox-Dark";
        gtk.package = pkgs.gruvbox-gtk-theme;

        cursor.name = "Bibata-Modern-Classic";
        cursor.package = pkgs.bibata-cursors;

        palettes.dark = {
          base = "#1d2021";
          surface = "#3c3836";
          overlay = "#504945";
          muted = "#928374";

          text = "#ebdbb2";
          subtext = "#bdae93";

          accent = "#8ec07c";
          accentText = "#1d2021";

          red = "#fb4934";
          green = "#b8bb26";
          yellow = "#fabd2f";
          blue = "#83a598";

          edgeLight = "#a89984";
          edgeShade = "#000000";
        };

        palettes.light = {
          base = "#f9f5d7";
          surface = "#fbf1c7";
          overlay = "#ebdbb2";
          muted = "#928374";

          text = "#3c3836";
          subtext = "#504945";

          accent = "#427b58";
          accentText = "#fbf1c7";

          red = "#9d0006";
          green = "#79740e";
          yellow = "#b57614";
          blue = "#076678";

          edgeLight = "#ffffff";
          edgeShade = "#7c6f64";
        };

        blur.enable = false;
      };
    };
}
