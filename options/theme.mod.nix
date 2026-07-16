{
  flake.nixosModules.theme =
    { lib, pkgs, ... }:
    let
      inherit (lib.modules) mkDefault;
      inherit (lib.options) mkOption;
      inherit (lib.types)
        bool
        float
        int
        nullOr
        package
        path
        str
        submodule
        ;

      # DESIGN TOKENS
      # DE-agnostic data every adapter reads. The default below is the base look;
      # a composed theme module (themes/*.mod.nix) overrides `theme` wholesale.
      colorOption = mkOption { type = str; };
    in
    {
      options.theme = mkOption {
        description = "Active theme tokens.";
        type = submodule {
          options = {
            name = mkOption {
              type = str;
              description = "Identifier of the active theme.";
            };

            cornerRadius = mkOption { type = int; };
            borderWidth = mkOption { type = int; };

            margin = mkOption { type = int; };
            padding = mkOption { type = int; };

            font.size.normal = mkOption { type = int; };
            font.size.big = mkOption { type = int; };

            font.sans.name = mkOption { type = str; };
            font.sans.package = mkOption { type = package; };

            font.mono.name = mkOption { type = str; };
            font.mono.package = mkOption { type = package; };

            icons.name = mkOption { type = str; };
            icons.package = mkOption { type = package; };

            gtk.name = mkOption { type = str; };
            gtk.package = mkOption { type = package; };

            cursor.name = mkOption { type = str; };
            cursor.package = mkOption { type = package; };
            cursor.size = mkOption {
              type = int;
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
              type = int;
              default = 0;
            };
            blur.opacity = mkOption {
              type = float;
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
        };

        blur.enable = false;
      };
    };
}
