{ inputs, ... }:
{
  # DANKMATERIALSHELL (Tahoe / liquid glass)
  # DMS's home option is a home-manager module, which this repo does not use, so
  # we take its NixOS module instead (installs the shell to /etc/xdg/quickshell
  # + the `dms` CLI). Pure: only composed into hosts that want it.
  desktopModules.dms =
    {
      config,
      lib,
      pkgs,
      ...
    }:
    let
      inherit (lib.attrsets) mapAttrsRecursive;
      inherit (lib.modules) mkDefault mkIf;
      inherit (lib.options) mkOption;
      inherit (lib.types)
        addCheck
        bool
        enum
        float
        listOf
        nonEmptyStr
        str
        submodule
        ;
      inherit (lib.types.ints) unsigned;

      inherit (config) theme;

      # Opacities and transparencies are fractions of 1, the same as
      # `theme.blur.opacity`. Typed as such rather than as a bare float: DMS
      # reads a 60 where it wanted 0.6 as "fully opaque, no complaints".
      fraction = addCheck float (value: value >= 0.0 && value <= 1.0);

      # PER-LEAF DEFAULTS
      # `mkDefault` on the whole attrset is a single definition at one
      # priority: a host that sets one field defines the option at a higher
      # priority, `filterOverrides` then drops the default definition whole,
      # and every field the host did not mention is suddenly unset. Applying
      # it per leaf instead makes each field default on its own, which is what
      # "a host can override any field" has always claimed.
      defaults = mapAttrsRecursive (_path: mkDefault);
    in
    {
      imports = [ inputs.dms.nixosModules.dank-material-shell ];

      # DMS BAR
      # Style/behavior knobs for DankBar, kept separate from `theme` because
      # they're DMS-specific (not DE-agnostic data every adapter reads) — but
      # still a host-overridable token declaration, not something baked into
      # the (pure) home module that renders it. Defaults below derive from
      # `theme` wherever a real mapping exists; a host can override any field
      # via `config.dmsBar.<field> = ...;` same as it overrides `theme`.
      options.dmsBar = mkOption {
        description = "DankMaterialShell DankBar style/behavior tokens.";
        type = submodule {
          options = {
            leftWidgets = mkOption { type = listOf str; };
            centerWidgets = mkOption { type = listOf str; };
            rightWidgets = mkOption { type = listOf str; };

            spacing = mkOption { type = unsigned; };
            innerPadding = mkOption { type = unsigned; };
            bottomGap = mkOption { type = unsigned; };

            transparency = mkOption { type = fraction; };
            widgetTransparency = mkOption { type = fraction; };

            squareCorners = mkOption { type = bool; };
            noBackground = mkOption { type = bool; };
            gothCornersEnabled = mkOption { type = bool; };
            gothCornerRadiusOverride = mkOption { type = bool; };
            gothCornerRadiusValue = mkOption { type = unsigned; };

            borderEnabled = mkOption { type = bool; };
            borderColor = mkOption { type = nonEmptyStr; };
            borderOpacity = mkOption { type = fraction; };
            borderThickness = mkOption { type = unsigned; };

            fontScale = mkOption { type = float; };

            autoHide = mkOption { type = bool; };
            autoHideDelay = mkOption { type = unsigned; };
            openOnOverview = mkOption { type = bool; };
            visible = mkOption { type = bool; };

            popupGapsAuto = mkOption { type = bool; };
            popupGapsManual = mkOption { type = unsigned; };

            widgetOutlineEnabled = mkOption { type = bool; };
            shadowIntensity = mkOption { type = unsigned; };
          };
        };
      };

      # DMS DOCK
      # Same shape and rationale as `dmsBar`. A dock is half of what makes the
      # Tahoe stack read as macOS rather than "a tiling WM with a bar", so it
      # is switched on here rather than left to the DMS settings UI (which
      # would not survive a rebuild — hjem replaces settings.json).
      options.dmsDock = mkOption {
        description = "DankMaterialShell dock style/behavior tokens.";
        type = submodule {
          options = {
            show = mkOption { type = bool; };
            autoHide = mkOption { type = bool; };
            smartAutoHide = mkOption { type = bool; };
            openOnOverview = mkOption { type = bool; };
            groupByApp = mkOption { type = bool; };

            # A dock with a Trash at the end of it is half of what makes a
            # dock read as macOS rather than as a launcher strip.
            showTrash = mkOption { type = bool; };

            position = mkOption { type = unsigned; };
            iconSize = mkOption { type = unsigned; };
            spacing = mkOption { type = unsigned; };
            bottomGap = mkOption { type = unsigned; };
            margin = mkOption { type = unsigned; };

            transparency = mkOption { type = fraction; };
            indicatorStyle = mkOption { type = nonEmptyStr; };

            borderEnabled = mkOption { type = bool; };
            borderColor = mkOption { type = nonEmptyStr; };
            borderOpacity = mkOption { type = fraction; };
            borderThickness = mkOption { type = unsigned; };

            launcherEnabled = mkOption { type = bool; };
          };
        };
      };

      # DMS SHELL
      # Everything that is neither the bar nor the dock: the glass, the
      # typography, the depth and the theming DMS would otherwise take over.
      # Same shape and rationale as `dmsBar`, with defaults derived from
      # `theme` wherever a real mapping exists.
      #
      # This surface used to be an untyped attrset inline in the home module,
      # which meant the only thing checking it was DMS — and DMS ignores what
      # it does not understand, so a value of the wrong shape was a rebuild
      # that changed nothing and said nothing. The key *names* are checked
      # against upstream's SettingsData.qml at build time (see the home module
      # below); this is the other half, checking the values.
      options.dmsShell = mkOption {
        description = "DankMaterialShell global (non-bar, non-dock) style tokens.";
        type = submodule {
          options = {
            cornerRadius = mkOption { type = unsigned; };
            popupTransparency = mkOption { type = fraction; };

            font.family = mkOption { type = nonEmptyStr; };
            font.mono = mkOption { type = nonEmptyStr; };
            font.scale = mkOption { type = float; };

            iconTheme = mkOption { type = nonEmptyStr; };

            blur.enable = mkOption { type = bool; };
            blur.foregroundLayers = mkOption { type = bool; };

            # The bright hairline along the lit edge of a pane of glass —
            # what separates one translucent surface from the one behind it,
            # and the detail Tahoe's liquid glass is mostly made of.
            blur.borderEnabled = mkOption { type = bool; };
            blur.borderOpacity = mkOption { type = fraction; };

            frame.enable = mkOption { type = bool; };
            frame.blur = mkOption { type = bool; };
            frame.opacity = mkOption { type = fraction; };
            frame.rounding = mkOption { type = unsigned; };
            frame.thickness = mkOption { type = unsigned; };
            frame.closeGaps = mkOption { type = bool; };

            # Glass floats above the wallpaper, so it casts a shadow. These
            # are DMS's Material elevation knobs, which are the only depth
            # controls it has — the look they are set to here is Apple's, not
            # Material's.
            elevation.enable = mkOption { type = bool; };
            elevation.intensity = mkOption { type = unsigned; };
            elevation.opacity = mkOption { type = unsigned; };
            elevation.bar = mkOption { type = bool; };
            elevation.popout = mkOption { type = bool; };
            elevation.modal = mkOption { type = bool; };

            rippleEffects = mkOption { type = bool; };
            waveProgress = mkOption { type = bool; };

            clock.format = mkOption {
              type = enum [
                "auto"
                "12h"
                "24h"
              ];
            };
            clock.showSeconds = mkOption { type = bool; };

            # Empty means "leave it to DMS"; `str` rather than `path` because
            # that empty string is a legitimate value here.
            lockWallpaper = mkOption { type = str; };

            gtkTheming = mkOption { type = bool; };
            qtTheming = mkOption { type = bool; };

            # CONTROL CENTRE
            # Field names are DMS's own JSON shape, so the list can be handed
            # to settings.json as-is. `width` is a percentage of the row: 50
            # is a half-width tile.
            controlCenterWidgets = mkOption {
              type = listOf (submodule {
                options = {
                  id = mkOption { type = nonEmptyStr; };
                  enabled = mkOption { type = bool; };
                  width = mkOption { type = unsigned; };
                };
              });
            };
          };
        };
      };

      config = {
        dmsBar = defaults {
          leftWidgets = [
            "launcherButton"
            "workspaceSwitcher"
            "focusedWindow"
          ];
          centerWidgets = [
            "music"
            "clock"
            "weather"
          ];
          rightWidgets = [
            "systemTray"
            "clipboard"
            "cpuUsage"
            "memUsage"
            "notificationButton"
            "battery"
            "controlCenterButton"
          ];

          spacing = 4;
          innerPadding = 4;
          bottomGap = 0;

          # GLASS: consistent with popup/dock, driven by the blur token.
          # noBackground drops the bar's own chrome on glass themes, relying
          # on the blurred backdrop instead of a flat pill; flat themes (blur
          # disabled) keep a real background since there's no blur to lean on.
          transparency = theme.blur.opacity;
          widgetTransparency = theme.blur.opacity;

          squareCorners = theme.cornerRadius == 0;
          noBackground = theme.blur.enable;
          gothCornersEnabled = false;
          gothCornerRadiusOverride = false;
          gothCornerRadiusValue = theme.cornerRadius;

          borderEnabled = false;
          borderColor = "surfaceText";
          borderOpacity = 1.0;
          borderThickness = theme.borderWidth;

          fontScale = 1.0;

          autoHide = false;
          autoHideDelay = 250;
          openOnOverview = false;
          visible = true;

          popupGapsAuto = true;
          popupGapsManual = 4;

          widgetOutlineEnabled = false;
          shadowIntensity = 0;
        };

        # The dock is only worth showing on a glass theme — on a flat one it
        # is an opaque slab of chrome the design does not call for, so `show`
        # tracks the same token everything else does.
        dmsDock = defaults {
          show = theme.blur.enable;
          autoHide = true;
          smartAutoHide = true;
          openOnOverview = true;
          groupByApp = true;
          showTrash = true;

          # 0 = bottom, matching SettingsData.Position.Bottom.
          position = 0;
          iconSize = 44;
          spacing = theme.margin;
          bottomGap = theme.margin;
          inherit (theme) margin;

          transparency = theme.blur.opacity;
          indicatorStyle = "circle";

          borderEnabled = false;
          borderColor = "surfaceText";
          borderOpacity = 1.0;
          borderThickness = theme.borderWidth;

          launcherEnabled = true;
        };

        dmsShell = defaults {
          inherit (theme) cornerRadius;
          popupTransparency = theme.blur.opacity;

          font.family = theme.font.sans.name;
          font.mono = theme.font.mono.name;
          font.scale = 1.0;

          iconTheme = theme.icons.name;

          blur.enable = theme.blur.enable;
          blur.foregroundLayers = theme.blur.enable;
          blur.borderEnabled = theme.blur.enable;
          blur.borderOpacity = 0.35;

          frame.enable = theme.blur.enable;
          frame.blur = theme.blur.enable;
          frame.opacity = theme.blur.opacity;
          frame.rounding = theme.cornerRadius;
          frame.thickness = theme.margin * 2;
          frame.closeGaps = true;

          elevation.enable = theme.blur.enable;
          elevation.intensity = 12;
          elevation.opacity = 30;
          elevation.bar = theme.blur.enable;
          elevation.popout = theme.blur.enable;
          elevation.modal = theme.blur.enable;

          # Ripples and wavy progress bars are Material 3 signatures. On a
          # stack dressed as macOS they are the two animations that give it
          # away, so they are off by default and a Material-looking host can
          # turn them back on.
          rippleEffects = false;
          waveProgress = false;

          # macOS runs a 12-hour menu-bar clock without seconds.
          clock.format = "12h";
          clock.showSeconds = false;

          # The lock screen is the one wallpaper surface DMS takes from
          # settings.json rather than over IPC, so it can be set declaratively
          # here even though the desktop wallpaper cannot.
          lockWallpaper = if theme.wallpaper == null then "" else toString theme.wallpaper;

          # This repo writes qt6ct and GTK itself (adapters/qt.mod.nix,
          # adapters/gtk.mod.nix). Left enabled, DMS writes its own colours
          # over both from its own palette.
          gtkTheming = false;
          qtTheming = false;

          # Toggles first and sliders last, which is the order stock Tahoe's
          # Control Centre uses; DMS ships the sliders on top.
          controlCenterWidgets =
            map
              (id: {
                inherit id;
                enabled = true;
                width = 50;
              })
              [
                "wifi"
                "bluetooth"
                "audioOutput"
                "audioInput"
                "nightMode"
                "darkMode"
                "brightnessSlider"
                "volumeSlider"
              ];
        };

        # Autostart via DMS's own user service (bound to
        # graphical-session.target, which niri-session provides) so the bar
        # does not depend on `dms` being on PATH. Static palette comes from
        # tokens, so disable wallpaper-driven theming.
        programs.dank-material-shell.enable = true;
        programs.dank-material-shell.systemd.enable = true;
        programs.dank-material-shell.enableDynamicTheming = false;

        # WALLPAPER
        # DMS draws its own wallpaper layer (covering swaybg and friends), and
        # its documented interface for it is IPC: `dms ipc call wallpaper set
        # <path>`. The shell's socket comes up asynchronously, so retry until
        # it accepts. User units do not get the system profile on PATH, so the
        # retry loop's deps are provided explicitly: `dms` itself, coreutils,
        # and quickshell — `dms ipc` shells out to `qs`, so without it the
        # call dies with `exec: "qs": … $PATH`.
        systemd.user.services.dms-wallpaper = mkIf (theme.wallpaper != null) {
          description = "Set the DMS wallpaper from theme tokens";
          wantedBy = [ "graphical-session.target" ];
          partOf = [ "graphical-session.target" ];
          after = [ "graphical-session.target" ];
          path = [
            config.programs.dank-material-shell.package
            pkgs.quickshell
            pkgs.coreutils
          ];
          serviceConfig.Type = "oneshot";
          script = /* bash */ ''
            set -euo pipefail
            for _ in $(seq 30); do
              if dms ipc call wallpaper set "${theme.wallpaper}"; then
                exit 0
              fi
              sleep 1
            done
            exit 1
          '';
        };
      };
    };

  desktopHomeModules.dms =
    {
      config,
      lib,
      osConfig,
      pkgs,
      ...
    }:
    let
      inherit (lib.attrsets) attrNames;
      inherit (lib.strings) concatStringsSep;

      inherit (osConfig)
        dmsBar
        dmsDock
        dmsShell
        theme
        ;
      inherit (theme) palette;

      themeFile = "${config.directory}/.config/DankMaterialShell/dank-theme.json";

      # DMS reads barConfigs as a whole object per bar, so the fixed identity
      # fields (which bar this is, where it lives) are supplied here — those
      # aren't style/behavior tokens, `dmsBar` (declared in desktopModules.dms,
      # host-overridable) is. Recapture the widget layout in `dmsBar` if you
      # rearrange the bar in the DMS UI.
      barConfig = dmsBar // {
        id = "default";
        name = "Main Bar";
        enabled = true;
        position = 0;
        screenPreferences = [ "all" ];
        showOnLastDisplay = true;
      };

      # DMS owns settings.json's schema and ignores keys it does not know, so
      # a renamed or misspelled setting is silently inert — the failure mode is
      # a rebuild that changes nothing and no error anywhere. This is the whole
      # settings surface we write, kept as data so it can be checked.
      settings = {
        currentThemeName = "custom";
        customThemeFile = themeFile;

        # THEMING OWNERSHIP
        # DMS can write GTK and qt6ct configuration of its own; this repo
        # already does (adapters/gtk.mod.nix, adapters/qt.mod.nix), so it is
        # told not to rather than left to race us for the same files.
        gtkThemingEnabled = dmsShell.gtkTheming;
        qtThemingEnabled = dmsShell.qtTheming;

        # TYPOGRAPHY
        # Unset, DMS renders in its own bundled defaults (Inter Variable /
        # Fira Code) while every other surface in the session uses the theme's
        # fonts — a mismatch that is most of what makes a themed desktop look
        # assembled rather than designed.
        fontFamily = dmsShell.font.family;
        monoFontFamily = dmsShell.font.mono;
        fontScale = dmsShell.font.scale;

        # Both variants: `iconThemePerMode` is off, so either can be the one
        # DMS reads, and the theme only ships one icon set anyway.
        iconThemeDark = dmsShell.iconTheme;
        iconThemeLight = dmsShell.iconTheme;

        # DMS rounds its own surfaces independently of the compositor's window
        # corners, so without this the panels stay at Material's 12px while
        # every window is at the theme's radius.
        inherit (dmsShell) cornerRadius;

        blurEnabled = dmsShell.blur.enable;
        blurForegroundLayers = dmsShell.blur.foregroundLayers;
        blurBorderEnabled = dmsShell.blur.borderEnabled;
        blurBorderOpacity = dmsShell.blur.borderOpacity;

        # DEPTH
        # A pane of glass that casts no shadow reads as a hole in the
        # wallpaper rather than as a surface above it.
        m3ElevationEnabled = dmsShell.elevation.enable;
        m3ElevationIntensity = dmsShell.elevation.intensity;
        m3ElevationOpacity = dmsShell.elevation.opacity;
        barElevationEnabled = dmsShell.elevation.bar;
        popoutElevationEnabled = dmsShell.elevation.popout;
        modalElevationEnabled = dmsShell.elevation.modal;

        enableRippleEffects = dmsShell.rippleEffects;
        waveProgressEnabled = dmsShell.waveProgress;

        clockFormat = dmsShell.clock.format;
        showSeconds = dmsShell.clock.showSeconds;

        lockScreenWallpaperPath = dmsShell.lockWallpaper;

        inherit (dmsShell) controlCenterWidgets;

        # GLASS
        # `frame*` draws DMS's rounded screen-edge frame — the detail that
        # makes the whole session read as one continuous pane of glass rather
        # than a bar floating over a wallpaper.
        frameEnabled = dmsShell.frame.enable;
        frameBlurEnabled = dmsShell.frame.blur;
        frameOpacity = dmsShell.frame.opacity;
        frameRounding = dmsShell.frame.rounding;
        frameThickness = dmsShell.frame.thickness;
        frameCloseGaps = dmsShell.frame.closeGaps;

        inherit (dmsShell) popupTransparency;
        dockTransparency = dmsDock.transparency;

        showDock = dmsDock.show;
        dockShowTrash = dmsDock.showTrash;
        dockAutoHide = dmsDock.autoHide;
        dockSmartAutoHide = dmsDock.smartAutoHide;
        dockOpenOnOverview = dmsDock.openOnOverview;
        dockGroupByApp = dmsDock.groupByApp;
        dockPosition = dmsDock.position;
        dockIconSize = dmsDock.iconSize;
        dockSpacing = dmsDock.spacing;
        dockBottomGap = dmsDock.bottomGap;
        dockMargin = dmsDock.margin;
        dockIndicatorStyle = dmsDock.indicatorStyle;
        dockBorderEnabled = dmsDock.borderEnabled;
        dockBorderColor = dmsDock.borderColor;
        dockBorderOpacity = dmsDock.borderOpacity;
        dockBorderThickness = dmsDock.borderThickness;
        dockLauncherEnabled = dmsDock.launcherEnabled;

        barConfigs = [ barConfig ];
      };

      # BUILD-TIME VALIDATION
      # Every top-level key above must exist as a `property` on DMS's
      # SettingsData.qml, which is the authoritative list for the pinned DMS.
      # Checking against upstream's source rather than a hand-copied allowlist
      # means this cannot drift: bump the `dms` input, and any setting that was
      # renamed or dropped fails the build instead of silently doing nothing.
      settingsJson =
        pkgs.runCommand "dms-settings.json"
          {
            nativeBuildInputs = [ pkgs.jq ];
            passAsFile = [ "keys" ];
            keys = concatStringsSep "\n" (attrNames settings);
          }
          ''
            known="$(mktemp)"
            grep -oP '^\s*property\s+\S+\s+\K\w+' \
              ${inputs.dms}/quickshell/Common/SettingsData.qml | sort -u > "$known"

            unknown="$(comm -23 <(sort -u "$keysPath") "$known")"
            if [ -n "$unknown" ]; then
              echo "settings.json keys not present in this DankMaterialShell:" >&2
              echo "$unknown" >&2
              exit 1
            fi

            cp ${pkgs.writers.writeJSON "dms-settings-unchecked.json" settings} $out
          '';
    in
    {
      # DMS THEME
      # DMS's documented custom-theme mechanism (docs/CUSTOM_THEMES.md): a JSON
      # file of Material 3 color roles, activated from settings.json via
      # currentThemeName = "custom". Tokens map onto the roles below; a flat
      # (variant-less) definition applies to both light and dark modes.
      xdg.config.files."DankMaterialShell/dank-theme.json" = {
        generator = pkgs.writers.writeJSON "dms-theme.json";
        value = {
          inherit (theme) name;

          primary = palette.accent.hex;
          primaryText = palette.accentText.hex;
          primaryContainer = palette.overlay.hex;
          secondary = palette.blue.hex;

          surface = palette.surface.hex;
          surfaceText = palette.text.hex;
          surfaceVariant = palette.overlay.hex;
          surfaceVariantText = palette.subtext.hex;
          surfaceTint = palette.accent.hex;

          background = palette.base.hex;
          backgroundText = palette.text.hex;
          outline = palette.muted.hex;

          surfaceContainer = palette.surface.hex;
          surfaceContainerHigh = palette.overlay.hex;
          surfaceContainerHighest = palette.overlay.hex;

          error = palette.red.hex;
          warning = palette.yellow.hex;
          info = palette.blue.hex;
        };
      };

      # hjem replaces this file on every rebuild, so anything tweaked in the
      # DMS settings UI is lost — the tokens above are the source of truth.
      xdg.config.files."DankMaterialShell/settings.json".source = settingsJson;
    };
}
