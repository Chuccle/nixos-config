{
  desktopModules.labwc =
    {
      config,
      lib,
      pkgs,
      ...
    }:
    let
      inherit (lib.attrsets) mapAttrsToList;
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
    in
    {
      # LABWC CONFIG SCHEMA
      # A typed surface over rc.xml rather than a hand-written document. The
      # types below are what make a mistake visible at evaluation: a keybind
      # whose action is missing a `name`, or a gap given as a string, fails
      # `nixos-rebuild` rather than being skipped by labwc's lenient parser
      # with a log line nobody reads.
      #
      # Shape follows `pkgs.formats.xml`'s badgerfish convention, which is what
      # renders it: "@key" is an attribute, a list repeats an element.
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

        # WLR_RENDERER_ALLOW_SOFTWARE lets wlroots fall back to llvmpipe, so
        # the stack still comes up in VMs without GPU acceleration (virgl).
        # WLR_NO_HARDWARE_CURSORS: without GPU accel, wlroots still hands the
        # cursor to the virtual GPU's hardware cursor plane, whose format/
        # orientation QEMU's virtual display gets wrong — renders as an
        # upside-down cursor regardless of theme. Forces software cursor
        # compositing instead.
        # XCURSOR_THEME/SIZE: greetd execs this directly with no PAM/login-shell
        # step in between, so the generic `environment.sessionVariables` set in
        # cursor-icons.mod.nix never reaches this process (confirmed live —
        # labwc logged "Environment variable $XCURSOR_THEME not set, ignoring."
        # and fell back to its built-in placeholder cursor). Set explicitly
        # here, same as labwc's own FAQ recommends. All prefixed via `env`
        # (not a wrapper script) because greetd execs the command without a
        # shell.
        desktop.sessionCommand = "${getExe' pkgs.coreutils "env"} WLR_RENDERER_ALLOW_SOFTWARE=1 WLR_NO_HARDWARE_CURSORS=1 XCURSOR_THEME=${config.theme.cursor.name} XCURSOR_SIZE=${toString config.theme.cursor.size} ${getExe pkgs.labwc}";

        # SESSION BASELINE
        # The niri stack gets these via nixpkgs' programs.niri -> wayland-session;
        # labwc has no nixpkgs module, so enable the GPU userspace stack (mesa at
        # /run/opengl-driver — labwc and quickshell need EGL) and polkit here.
        services.graphical-desktop.enable = true;
        security.polkit.enable = true;

        # Win95 was strictly stacking, gapless, click-to-focus — and the
        # muscle memory is Alt+Tab / Alt+F4 / Win+E / Win+D.
        labwcConfig = mkDefault {
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
                  command = getExe pkgs.foot;
                };
                "A-Return" = {
                  "@name" = "Execute";
                  command = getExe pkgs.foot;
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

      # labwc themerc uses `key: value`, so generate it with a colon separator
      # rather than ini's `key=value`.
      themerc = toKeyValue { mkKeyValue = mkKeyValueDefault { } ": "; };

      # rc.xml goes through the stock `pkgs.formats.xml` writer (badgerfish
      # convention: `@` prefixes an attribute, a list repeats an element).
      # Nothing bespoke to maintain, and the writer runs xmllint over its own
      # output — so a malformed document is a build failure either way.
      xml = pkgs.formats.xml { };
    in
    {
      # LABWC CONFIG
      # Stacking Wayland compositor for the Win95 stack. The document is a
      # typed Nix value (see `labwcConfig` in desktopModules.labwc), so a
      # mistyped keybind is an evaluation error rather than a silently ignored
      # element.
      xdg.config.files."labwc/rc.xml".source = xml.generate "rc.xml" {
        labwc_config = labwcConfig;
      };

      # THEMERC-OVERRIDE
      # Navy active titlebar, silver chrome, 2px bevels — straight from tokens.
      # Title left-justified and shadows disabled to keep the flat, hard-edged
      # Win95 look rather than a modern soft-blurred titlebar.
      xdg.config.files."labwc/themerc-override".text = themerc {
        "border.width" = theme.borderWidth;
        "padding.height" = theme.padding;

        "window.label.text.justify" = "Left";

        "window.active.title.bg.color" = palette.accent;
        "window.active.label.text.color" = palette.accentText;
        "window.active.border.color" = palette.muted;

        "window.inactive.title.bg.color" = palette.muted;
        "window.inactive.label.text.color" = palette.subtext;
        "window.inactive.border.color" = palette.muted;

        "window.active.button.unpressed.image.color" = palette.accentText;
        "window.inactive.button.unpressed.image.color" = palette.subtext;
        "window.button.hover.bg.color" = palette.overlay;
        "window.button.hover.bg.corner-radius" = theme.cornerRadius;

        "window.active.shadow.size" = 0;
        "window.inactive.shadow.size" = 0;

        "menu.items.bg.color" = palette.surface;
        "menu.items.text.color" = palette.text;
        "menu.items.active.bg.color" = palette.accent;
        "menu.items.active.text.color" = palette.accentText;

        "osd.bg.color" = palette.surface;
        "osd.border.color" = palette.muted;
        "osd.border.width" = theme.borderWidth;
        "osd.label.text.color" = palette.text;
      };

      # AUTOSTART
      # Sourced by labwc via sh, so no executable bit is needed. Absolute store
      # paths rather than bare names: labwc inherits greetd's environment,
      # which does not carry the user's profile PATH.
      xdg.config.files."labwc/autostart".text = /* bash */ ''
        ${getExe pkgs.quickshell} -c win95 &
        ${getExe pkgs.swaybg} -c ${removePrefix "#" palette.base} &
      '';
    };
}
