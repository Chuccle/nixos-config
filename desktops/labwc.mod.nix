{
  desktopModules.labwc =
    {
      config,
      lib,
      pkgs,
      ...
    }:
    let
      inherit (lib.attrsets) mapAttrsRecursive mapAttrsToList;
      inherit (lib.meta) getExe getExe';
      inherit (lib.modules) mkDefault;
      inherit (lib.options) mkOption;
      inherit (lib.types)
        attrsOf
        either
        int
        listOf
        str
        submodule
        ;

      # PER-LEAF DEFAULTS
      defaults = mapAttrsRecursive (_path: mkDefault);
    in
    {
      # LABWC CONFIG SCHEMA
      options.labwcConfig = mkOption {
        description = "labwc rc.xml document, rendered by pkgs.formats.xml.";
        type = submodule {
          options = {
            core = mkOption {
              type = attrsOf (either int str);
              description = "Core compositor behaviour.";
            };

            focus = mkOption {
              type = attrsOf str;
              description = "Focus model.";
            };

            keyboard.keybind = mkOption {
              description = "Key chords and the actions they fire.";
              type = listOf (submodule {
                options = {
                  "@key" = mkOption {
                    type = str;
                    description = "Chord, in labwc's W-/A-/C-/S- notation.";
                  };
                  action = mkOption {
                    type = attrsOf str;
                    description = "Action fired by the chord: `@name` is the labwc action, remaining keys are its parameters (`command` for Execute). Absent keys render as absent elements.";
                  };
                };
              });
            };
          };
        };
      };

      config = {
        environment.systemPackages = [
          pkgs.labwc
          pkgs.quickshell
          pkgs.swaybg
        ];

        desktop.sessionCommand = "${getExe' pkgs.coreutils "env"} WLR_RENDERER_ALLOW_SOFTWARE=1 WLR_NO_HARDWARE_CURSORS=1 XCURSOR_THEME=${config.theme.cursor.name} XCURSOR_SIZE=${toString config.theme.cursor.size} ${getExe pkgs.labwc}";

        # SESSION BASELINE
        services.graphical-desktop.enable = true;
        security.polkit.enable = true;

        labwcConfig = defaults {
          core = {
            gap = 0;
            adaptiveSync = "no";
          };

          focus = {
            followMouse = "no";
            raiseOnFocus = "yes";
          };

          keyboard.keybind =
            mapAttrsToList
              (chord: action: {
                "@key" = chord;
                inherit action;
              })
              {
                "W-Return" = {
                  "@name" = "Execute";
                  command = getExe pkgs.ghostty;
                };
                "A-Return" = {
                  "@name" = "Execute";
                  command = getExe pkgs.ghostty;
                };
                "W-e" = {
                  "@name" = "Execute";
                  command = getExe pkgs.kdePackages.dolphin;
                };

                "W-q" = {
                  "@name" = "Close";
                };
                "A-F4" = {
                  "@name" = "Close";
                };

                "A-Tab" = {
                  "@name" = "NextWindow";
                };
                "A-S-Tab" = {
                  "@name" = "PreviousWindow";
                };

                "W-d" = {
                  "@name" = "ToggleShowDesktop";
                };
                "W-Up" = {
                  "@name" = "ToggleMaximize";
                };
                "W-Down" = {
                  "@name" = "Iconify";
                };
              };
        };
      };
    };

  desktopHomeModules.labwc =
    {
      lib,
      osConfig,
      pkgs,
      ...
    }:
    let
      inherit (lib.generators) mkKeyValueDefault toKeyValue;
      inherit (lib.meta) getExe;
      inherit (lib.strings) removePrefix;
      inherit (osConfig) labwcConfig theme;
      inherit (theme) palette;

      themerc = toKeyValue { mkKeyValue = mkKeyValueDefault { } ": "; };

      xml = pkgs.formats.xml { };
    in
    {
      # LABWC CONFIG
      xdg.config.files."labwc/rc.xml".source = xml.generate "rc.xml" {
        labwc_config = labwcConfig;
      };

      # THEMERC-OVERRIDE
      xdg.config.files."labwc/themerc-override".text = themerc {
        "border.width" = theme.borderWidth;
        "padding.height" = theme.padding;

        "window.label.text.justify" = "Left";

        "window.active.title.bg.color" = palette.accent.hex;
        "window.active.label.text.color" = palette.accentText.hex;
        "window.active.border.color" = palette.muted.hex;

        "window.inactive.title.bg.color" = palette.muted.hex;
        "window.inactive.label.text.color" = palette.subtext.hex;
        "window.inactive.border.color" = palette.muted.hex;

        "window.active.button.unpressed.image.color" = palette.accentText.hex;
        "window.inactive.button.unpressed.image.color" = palette.subtext.hex;
        "window.button.hover.bg.color" = palette.overlay.hex;
        "window.button.hover.bg.corner-radius" = theme.cornerRadius;

        "window.active.shadow.size" = 0;
        "window.inactive.shadow.size" = 0;

        "menu.items.bg.color" = palette.surface.hex;
        "menu.items.text.color" = palette.text.hex;
        "menu.items.active.bg.color" = palette.accent.hex;
        "menu.items.active.text.color" = palette.accentText.hex;

        "osd.bg.color" = palette.surface.hex;
        "osd.border.color" = palette.muted.hex;
        "osd.border.width" = theme.borderWidth;
        "osd.label.text.color" = palette.text.hex;
      };

      # AUTOSTART
      xdg.config.files."labwc/autostart".text = /* bash */ ''
        ${getExe pkgs.quickshell} -c win95 &
        ${getExe pkgs.swaybg} -c ${removePrefix "#" palette.base.hex} &
      '';
    };
}
