{
  desktopModules.niri =
    { lib, pkgs, ... }:
    let
      inherit (lib.meta) getExe';
      inherit (lib.modules) mkDefault;
      inherit (lib.options) mkOption;
      inherit (lib.types) int str submodule;
    in
    {
      # NIRI SHADOW
      # Style knobs for the glass-mode window shadow — DE-specific (not a
      # `theme.*` field every adapter reads), but still a host-overridable
      # token declaration rather than literals baked into the home module,
      # same shape as `dmsBar` in shells/dms.mod.nix.
      options.niriShadow = mkOption {
        description = "niri glass-mode window shadow tokens.";
        type = submodule {
          options = {
            softness = mkOption { type = int; };
            spread = mkOption { type = int; };
            offsetX = mkOption { type = int; };
            offsetY = mkOption { type = int; };
            # Hex alpha byte (00-ff) appended to `theme.palette.base`, not a
            # 0-1 float, so it can be spliced directly into the KDL color
            # string without a float->hex conversion helper.
            opacityHex = mkOption { type = str; };
          };
        };
      };

      config = {
        programs.niri.enable = true;

        # niri spawns xwayland-satellite from PATH for X11 apps; without it,
        # Xwayland integration is silently disabled.
        environment.systemPackages = [ pkgs.xwayland-satellite ];

        # `niri-session` (not `niri --session`) runs niri as a systemd user
        # service, which activates graphical-session.target — the target the
        # DMS user service and portals bind to. Launching the bare binary
        # leaves that target inactive and the session empty.
        desktop.sessionCommand = getExe' pkgs.niri "niri-session";

        niriShadow = mkDefault {
          softness = 40;
          spread = 4;
          offsetX = 0;
          offsetY = 8;
          opacityHex = "b3";
        };
      };
    };

  desktopHomeModules.niri =
    { lib, osConfig, ... }:
    let
      inherit (lib.strings) optionalString;
      inherit (osConfig) niriShadow theme;
      inherit (theme) palette;

      glass = theme.blur.enable;
    in
    {
      # NIRI CONFIG
      # Scrollable-tiling compositor for the Tahoe stack. Gaps/border come from
      # tokens; DankMaterialShell starts via its systemd user service, and Mod+D
      # toggles its launcher. Routed through rum.desktops.niri (not our own
      # xdg.config.files) so the generated config.kdl gets `niri validate -c`
      # at build time instead of being entirely unchecked until runtime.
      rum.desktops.niri.enable = true;
      rum.desktops.niri.config = /* kdl */ ''
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
                  softness ${toString niriShadow.softness}
                  spread ${toString niriShadow.spread}
                  offset x=${toString niriShadow.offsetX} y=${toString niriShadow.offsetY}
                  color "${palette.base}${niriShadow.opacityHex}"
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
