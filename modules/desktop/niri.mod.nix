{ inputs, lib, ... }:
let
  inherit (lib.lists) singleton;
in
{
  flake.nixosModules.desktop-niri =
    {
      config,
      lib,
      pkgs,
      ...
    }:
    let
      inherit (lib.meta) getExe;
    in
    {
      imports = singleton inputs.niri.lib.internal.settings-module;

      config.environment.sessionVariables = {
        XCURSOR_THEME = config.programs.niri.settings.cursor.theme;
        XCURSOR_SIZE = toString config.programs.niri.settings.cursor.size;
      };

      config.environment.systemPackages = singleton pkgs.kdePackages.breeze;

      config.programs.niri = {
        settings = {
          prefer-no-csd = true;

          hotkey-overlay.skip-at-startup = true;

          input.touchpad = {
            tap = true;
            natural-scroll = true;
            dwt = true;
          };

          cursor = {
            theme = "breeze_cursors";
            size = 24;
          };

          layout = {
            gaps = 16;

            center-focused-column = "on-overflow";

            default-column-width.proportion = 0.5;

            preset-column-widths = [
              { proportion = 1.0 / 3.0; }
              { proportion = 0.5; }
              { proportion = 2.0 / 3.0; }
            ];

            border.enable = false;
            focus-ring.enable = false;
            shadow.enable = false;
          };

          window-rules = [
            {
              geometry-corner-radius = {
                top-left = 20.0;
                top-right = 20.0;
                bottom-right = 20.0;
                bottom-left = 20.0;
              };

              clip-to-geometry = true;
            }
            {
              matches = singleton { is-floating = true; };

              geometry-corner-radius = {
                top-left = 8.0;
                top-right = 8.0;
                bottom-right = 8.0;
                bottom-left = 8.0;
              };

              border = {
                enable = true;
                width = 2;
                active.color = "#d0d0d0";
                inactive.color = "#666666";
              };

              shadow = {
                enable = true;
                offset = {
                  x = 0;
                  y = 6;
                };
                softness = 24;
                spread = 0;
                color = "#00000080";
              };
            }
          ];

          xwayland-satellite.path = getExe pkgs.xwayland-satellite;

          binds = {
            "Mod+Return".action.spawn = singleton <| getExe pkgs.ghostty;
            "Mod+E".action.spawn = singleton <| getExe pkgs.kdePackages.dolphin;

            "Mod+Q".action.close-window = [ ];

            "Mod+H".action.focus-column-left = [ ];
            "Mod+J".action.focus-window-down = [ ];
            "Mod+K".action.focus-window-up = [ ];
            "Mod+L".action.focus-column-right = [ ];

            "Mod+Shift+H".action.move-column-left = [ ];
            "Mod+Shift+J".action.move-window-down = [ ];
            "Mod+Shift+K".action.move-window-up = [ ];
            "Mod+Shift+L".action.move-column-right = [ ];

            "Mod+U".action.focus-workspace-down = [ ];
            "Mod+I".action.focus-workspace-up = [ ];
            "Mod+Shift+U".action.move-column-to-workspace-down = [ ];
            "Mod+Shift+I".action.move-column-to-workspace-up = [ ];

            "Mod+WheelScrollDown" = {
              cooldown-ms = 150;
              action.focus-workspace-down = [ ];
            };

            "Mod+WheelScrollUp" = {
              cooldown-ms = 150;
              action.focus-workspace-up = [ ];
            };

            "Mod+F".action.maximize-column = [ ];
            "Mod+Shift+F".action.fullscreen-window = [ ];
            "Mod+C".action.center-column = [ ];
            "Mod+R".action.switch-preset-column-width = [ ];
            "Mod+Shift+R".action.switch-preset-window-height = [ ];
            "Mod+V".action.toggle-window-floating = [ ];
            "Mod+Tab".action.toggle-overview = [ ];

            "Mod+BracketLeft".action.consume-or-expel-window-left = [ ];
            "Mod+BracketRight".action.consume-or-expel-window-right = [ ];

            "Print".action.screenshot = [ ];
            "Mod+Print".action.screenshot-window = [ ];
            "Mod+Shift+Print".action.screenshot-screen = [ ];
          };
        };
      };
    };

  flake.homeModules.desktop-niri =
    { osConfig, pkgs, ... }:
    {
      config = {
        xdg.config.files."niri/config.kdl".source =
          inputs.niri.lib.internal.validated-config-for pkgs osConfig.programs.niri.package
            osConfig.programs.niri.finalConfig;

        rum.misc.gtk.settings = {
          cursor-theme-name = osConfig.programs.niri.settings.cursor.theme;
          cursor-theme-size = osConfig.programs.niri.settings.cursor.size;
        };
      };
    };
}
