{
  flake.nixosModules.theme =
    { lib, pkgs, ... }:
    let
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
        float
        nonEmptyStr
        nullOr
        package
        path
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
      # DE-agnostic data every adapter reads. The default below is the base look;
      # a composed theme module (themes/*.mod.nix) overrides `theme` wholesale.

      # A colour token. Written as `#rrggbb` and read back as every spelling
      # the adapters need, because they do not agree on one: foot wants the
      # bare digits, qt6ct wants `#aarrggbb` with alpha first, KDE colour
      # schemes want a decimal triplet. Each of those used to be its own
      # helper — one in `lib/`, two inline — so the same conversion existed
      # three times and no consumer could see which spelling it was getting.
      #
      # `apply` puts them on the option instead. The conversion lives once,
      # beside the data it converts; the type checks the input on the way in,
      # so a mistyped token is an eval error rather than a colour that silently
      # renders black; and every adapter reads a named field, which says at the
      # call site which spelling it asked for.
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
    in
    {
      options.theme = mkOption {
        description = "Active theme tokens.";
        type = submodule {
          options = {
            # Spliced into generated file names (`qt6ct/colors/<name>.conf`),
            # so it is constrained to what is safe there rather than left as
            # free-form text.
            name = mkOption {
              type = strMatching "[a-z0-9-]+";
              description = "Identifier of the active theme.";
            };

            # Every geometry token is a distance in pixels: negative is never
            # meaningful, and `unsigned` says so at the type rather than
            # leaving a `-1` to surface as a rendering fault three adapters
            # downstream.
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
            # Hex strings (#rrggbb). Surfaces layer base -> surface -> overlay;
            # text/subtext/muted are foreground tiers; the rest are accents.
            palette = mkOption {
              type = submodule {
                options = {
                  base = colorOption;
                  surface = colorOption;
                  overlay = colorOption;
                  muted = colorOption;

                  text = colorOption;
                  subtext = colorOption;

                  accent = colorOption;
                  accentText = colorOption;

                  red = colorOption;
                  green = colorOption;
                  yellow = colorOption;
                  blue = colorOption;

                  # EDGES
                  # The two extreme tones an edge is drawn with: the lit side
                  # and the side in shadow. Win95's 3D chrome is literally
                  # white-on-black over silver, and Tahoe's glass is a bright
                  # specular hairline over a cast shadow — the same pair of
                  # roles, so both are one token pair rather than a constant
                  # inlined in a QML file and another in a KDL node.
                  edgeLight = colorOption;
                  edgeShade = colorOption;
                };
              };
            };

            # GLASS / BLUR
            # Drives the Aurora liquid-glass look. Flat themes set enable = false.
            blur.enable = mkOption {
              type = bool;
              default = false;
            };
            blur.radius = mkOption {
              type = unsigned;
              default = 0;
            };
            # A fraction, so the type says so: 0.6 is glass, 60 is a value
            # that silently renders every surface fully opaque wherever it is
            # read as a multiplier.
            blur.opacity = mkOption {
              type = addCheck float (opacity: opacity >= 0.0 && opacity <= 1.0);
              default = 1.0;
            };
          };
        };
      };

      # GRUVBOX (default, flat)
      # Base look; a composed theme module overrides this wholesale.
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

        palette = {
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

        blur.enable = false;
      };
    };
}
