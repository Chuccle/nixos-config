{
  desktopModules.niri =
    { lib, pkgs, ... }:
    let
      inherit (lib.meta) getExe';
    in
    {
      programs.niri.enable = true;

      # niri spawns xwayland-satellite from PATH for X11 apps; without it,
      # Xwayland integration is silently disabled.
      environment.systemPackages = [ pkgs.xwayland-satellite ];

      # `niri-session` (not `niri --session`) runs niri as a systemd user
      # service, which activates graphical-session.target — the target the DMS
      # user service and portals bind to. Launching the bare binary leaves that
      # target inactive and the session empty.
      desktop.sessionCommand = getExe' pkgs.niri "niri-session";
    };

  desktopHomeModules.niri =
    { lib, osConfig, ... }:
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

            // ALT DUPLICATES
            // Mod is Super, which host desktops swallow before it reaches a
            // VM guest window; keep the essentials reachable on Alt too.
            Alt+Return { spawn "foot"; }
            Alt+D { spawn "dms" "ipc" "call" "spotlight" "toggle"; }
            Alt+Q { close-window; }

            Alt+Left  { focus-column-left; }
            Alt+Right { focus-column-right; }
            Alt+Up    { focus-window-up; }
            Alt+Down  { focus-window-down; }

            Mod+1 { focus-workspace 1; }
            Mod+2 { focus-workspace 2; }
            Mod+3 { focus-workspace 3; }
            Mod+4 { focus-workspace 4; }

            Mod+Shift+E { quit; }
            Print { screenshot; }
        }

        // DMS INTEGRATION
        // DMS generates these snippets and manages them from its settings UI
        // (cursor, alt-tab, live colors, wallpaper blur). Last so they win
        // over the token defaults above; optional so missing ones are fine.
        include optional=true "~/.config/niri/dms/alttab.kdl"
        include optional=true "~/.config/niri/dms/binds.kdl"
        include optional=true "~/.config/niri/dms/colors.kdl"
        include optional=true "~/.config/niri/dms/cursor.kdl"
        include optional=true "~/.config/niri/dms/layout.kdl"
        include optional=true "~/.config/niri/dms/outputs.kdl"
        include optional=true "~/.config/niri/dms/windowrules.kdl"
        include optional=true "~/.config/niri/dms/wpblur.kdl"
      '';
    };
}
