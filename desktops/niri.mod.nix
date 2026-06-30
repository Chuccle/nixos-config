{
  desktopModules.niri =
    { lib, pkgs, ... }:
    let
      inherit (lib.meta) getExe;
    in
    {
      programs.niri.enable = true;
      desktop.sessionCommand = "${getExe pkgs.niri} --session";
    };

  desktopHomeModules.niri =
    { osConfig, lib, ... }:
    let
      inherit (lib.strings) optionalString;
      inherit (osConfig) theme;
      inherit (theme) palette;

      glass = theme.blur.enable;
    in
    {
      # NIRI CONFIG
      # Scrollable-tiling compositor for the Tahoe stack. Gaps/border come from
      # tokens; DankMaterialShell starts via its systemd user service, and Mod+D
      # toggles its launcher.
      xdg.config.files."niri/config.kdl".text = /* kdl */ ''
        input {
            keyboard {
                xkb { }
            }
            touchpad {
                tap
                natural-scroll
            }
        }

        layout {
            gaps ${toString theme.padding}
            center-focused-column "never"

            border {
                width ${toString theme.borderWidth}
                active-color "${theme.palette.accent}"
                inactive-color "${theme.palette.overlay}"
            }

            focus-ring {
                width ${toString theme.borderWidth}
                active-color "${theme.palette.accent}"
                inactive-color "${theme.palette.overlay}"
            }

            ${optionalString glass ''
              shadow {
                  on
                  softness 40
                  spread 4
                  offset x=0 y=8
                  color "${palette.base}b3"
              }
            ''}
        }

        prefer-no-csd

        window-rule {
            geometry-corner-radius ${toString theme.cornerRadius}
            clip-to-geometry true

            ${optionalString glass ''
              background-effect {
                  xray true
                  blur true
              }
            ''}
        }

        binds {
            Mod+Return { spawn "foot"; }
            Mod+D { spawn "dms" "ipc" "call" "spotlight" "toggle"; }
            Mod+Q { close-window; }

            Mod+Left  { focus-column-left; }
            Mod+Right { focus-column-right; }
            Mod+Up    { focus-window-up; }
            Mod+Down  { focus-window-down; }

            Mod+1 { focus-workspace 1; }
            Mod+2 { focus-workspace 2; }
            Mod+3 { focus-workspace 3; }
            Mod+4 { focus-workspace 4; }

            Mod+Shift+E { quit; }
            Print { screenshot; }
        }
      '';
    };
}
