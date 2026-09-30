{ inputs, ... }:
{
  desktopModules.dms =
    {
      config,
      lib,
      pkgs,
      ...
    }:
    let
      inherit (lib.attrsets) mapAttrsRecursive;
      inherit (lib.meta) getExe';
      inherit (lib.modules) mkDefault;
      inherit (lib.options) mkOption;
      inherit (lib.strings) optionalString;
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

      fraction = addCheck float (value: value >= 0.0 && value <= 1.0);

      # PER-LEAF DEFAULTS
      defaults = mapAttrsRecursive (_path: mkDefault);
    in
    {
      imports = [ inputs.dms.nixosModules.dank-material-shell ];

      # DMS BAR
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
      options.dmsDock = mkOption {
        description = "DankMaterialShell dock style/behavior tokens.";
        type = submodule {
          options = {
            show = mkOption { type = bool; };
            autoHide = mkOption { type = bool; };
            smartAutoHide = mkOption { type = bool; };
            openOnOverview = mkOption { type = bool; };
            groupByApp = mkOption { type = bool; };

            showTrash = mkOption { type = bool; };

            enlargeOnHover = mkOption { type = bool; };
            enlargePercentage = mkOption { type = unsigned; };

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
            pinnedApps = mkOption { type = listOf nonEmptyStr; };
          };
        };
      };

      # DMS SHELL
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

            blur.borderEnabled = mkOption { type = bool; };
            blur.borderColor = mkOption {
              type = enum [
                "outline"
                "primary"
                "secondary"
                "surfaceText"
                "custom"
              ];
            };
            blur.borderCustomColor = mkOption { type = nonEmptyStr; };
            blur.borderOpacity = mkOption { type = fraction; };

            frame.enable = mkOption { type = bool; };
            frame.blur = mkOption { type = bool; };
            frame.opacity = mkOption { type = fraction; };
            frame.rounding = mkOption { type = unsigned; };
            frame.thickness = mkOption { type = unsigned; };
            frame.closeGaps = mkOption { type = bool; };

            elevation.enable = mkOption { type = bool; };
            elevation.intensity = mkOption { type = unsigned; };
            elevation.opacity = mkOption { type = unsigned; };
            elevation.bar = mkOption { type = bool; };
            elevation.popout = mkOption { type = bool; };
            elevation.modal = mkOption { type = bool; };

            rippleEffects = mkOption { type = bool; };
            waveProgress = mkOption { type = bool; };

            trayIconTint = mkOption {
              type = enum [
                "none"
                "monochrome"
                "primary"
                "secondary"
              ];
            };

            # macOS names the focused app in bold and shows no icon for it.
            focusedWindow.showIcon = mkOption { type = bool; };

            applyAppearanceAtStartup = mkOption { type = bool; };

            launcherStyle = mkOption {
              type = enum [
                "full"
                "spotlight"
              ];
            };

            clock.format = mkOption {
              type = enum [
                "auto"
                "12h"
                "24h"
              ];
            };
            clock.showSeconds = mkOption { type = bool; };

            # Qt locale date pattern, or "" for the system default.
            clock.dateFormat = mkOption { type = str; };

            lockWallpaper = mkOption { type = str; };

            gtkTheming = mkOption { type = bool; };
            qtTheming = mkOption { type = bool; };

            # CONTROL CENTRE
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
        niriSession.shell = "dms";

        dmsBar = defaults {
          # MENU BAR
          leftWidgets = [
            "launcherButton"
            "workspaceSwitcher"
            "focusedWindow"
          ];
          centerWidgets = [ ];
          rightWidgets = [
            "music"
            "systemTray"
            "battery"
            "controlCenterButton"
            "notificationButton"
            "clock"
          ];

          spacing = 0;
          innerPadding = 0;
          bottomGap = 0;

          transparency = 0.15;
          widgetTransparency = 0.1;

          squareCorners = true;
          noBackground = false;
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

        dmsDock = defaults {
          show = theme.blur.enable;
          autoHide = true;
          smartAutoHide = true;
          openOnOverview = true;
          groupByApp = true;
          showTrash = true;

          enlargeOnHover = true;
          enlargePercentage = 130;

          # SettingsData.Position.Bottom in the locked DMS version.
          position = 1;
          pinnedApps = [
            "com.mitchellh.ghostty"
            "org.kde.dolphin"
            "org.kde.ark"
            "helium"
            "com.hex_rays.IDA.pro._9_4"
          ];
          iconSize = 44;
          spacing = theme.margin;
          bottomGap = theme.margin;
          inherit (theme) margin;

          transparency = 0.22;
          indicatorStyle = "circle";

          borderEnabled = theme.blur.enable;
          borderColor = "surface";
          borderOpacity = 0.55;
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
          # Upstream's transparent blur material keeps controls translucent.
          blur.foregroundLayers = false;
          blur.borderEnabled = theme.blur.enable;
          blur.borderColor = "custom";
          blur.borderCustomColor = theme.palette.edgeLight.hex;
          blur.borderOpacity = 0.55;

          frame.enable = false;
          frame.blur = false;
          frame.opacity = theme.blur.opacity;
          frame.rounding = theme.cornerRadius;
          frame.thickness = theme.margin * 2;
          frame.closeGaps = false;

          elevation.enable = theme.blur.enable;
          elevation.intensity = 12;
          elevation.opacity = 30;

          elevation.bar = false;
          elevation.popout = theme.blur.enable;
          elevation.modal = theme.blur.enable;

          rippleEffects = false;
          waveProgress = false;

          trayIconTint = "monochrome";
          focusedWindow.showIcon = false;
          # The packaged grid avoids Spotlight's partially clipped list row.
          launcherStyle = "full";
          applyAppearanceAtStartup = true;

          clock.format = "12h";
          clock.showSeconds = false;
          clock.dateFormat = "ddd MMM d";

          lockWallpaper = if theme.wallpaper == null then "" else toString theme.wallpaper;

          gtkTheming = false;
          qtTheming = false;

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

        programs.dank-material-shell.enable = true;
        programs.dank-material-shell.systemd.enable = true;
        programs.dank-material-shell.enableDynamicTheming = false;
        systemd.user.services.dms.environment.PATH =
          "/etc/profiles/per-user/%u/bin:/run/current-system/sw/bin";

        systemd.user.services.dms-session-defaults = {
          description = "Initialize the live desktop dock";
          wantedBy = [ "graphical-session.target" ];
          before = [ "dms.service" ];
          unitConfig.ConditionPathExists = "!%h/.local/state/DankMaterialShell/session.json";
          serviceConfig = {
            Type = "oneshot";
            ExecStart = "${getExe' pkgs.coreutils "install"} -Dm0600 ${
              pkgs.writers.writeJSON "dms-session-defaults.json" {
                inherit (config.dmsDock) pinnedApps;
              }
            } %h/.local/state/DankMaterialShell/session.json";
          };
        };

        # APPEARANCE AND WALLPAPER
        systemd.user.paths.ghostty-color-theme = {
          description = "Watch the shell appearance for Ghostty";
          wantedBy = [ "graphical-session.target" ];
          partOf = [ "graphical-session.target" ];
          pathConfig.PathChanged = "%h/.local/state/DankMaterialShell";
        };

        systemd.user.services.ghostty-color-theme = {
          description = "Apply the shell appearance to Ghostty";
          wantedBy = [ "graphical-session.target" ];
          path = [
            pkgs.coreutils
            pkgs.jq
            pkgs.procps
          ];
          serviceConfig.Type = "oneshot";
          script = /* bash */ ''
            set -euo pipefail
            state="$HOME/.local/state/DankMaterialShell/session.json"
            [ -e "$state" ] || exit 0

            appearance="$HOME/.local/state/ghostty/appearance"
            if [ "$(jq -r '.isLightMode // false' "$state")" = "true" ]; then
              install -Dm0600 ${
                (pkgs.formats.keyValue { }).generate "ghostty-light-appearance" {
                  theme = "desktop-light";
                }
              } "$appearance"
            else
              install -Dm0600 ${
                (pkgs.formats.keyValue { }).generate "ghostty-dark-appearance" {
                  theme = "desktop-dark";
                }
              } "$appearance"
            fi
            pkill --require-handler -USR2 -x 'ghostty|\.ghostty-wrappe' || true
          '';
        };

        systemd.user.services.dms-appearance = {
          description = "Apply the theme's appearance and wallpaper to DMS";
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
              if dms ipc call theme ${
                if config.dmsShell.applyAppearanceAtStartup then theme.appearance else "getMode"
              }; then
                ${optionalString (theme.wallpaper != null) ''dms ipc call wallpaper set "${theme.wallpaper}"''}
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

      roles = palette: {
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

      barConfig = dmsBar // {
        id = "default";
        name = "Main Bar";
        enabled = true;
        position = 0;
        screenPreferences = [ "all" ];
        showOnLastDisplay = true;
      };

      settings = {
        currentThemeName = "custom";
        customThemeFile = themeFile;

        # THEMING OWNERSHIP
        gtkThemingEnabled = dmsShell.gtkTheming;
        qtThemingEnabled = dmsShell.qtTheming;

        # TYPOGRAPHY
        fontFamily = dmsShell.font.family;
        monoFontFamily = dmsShell.font.mono;
        fontScale = dmsShell.font.scale;

        iconThemeDark = dmsShell.iconTheme;
        iconThemeLight = dmsShell.iconTheme;

        inherit (dmsShell) cornerRadius;

        blurEnabled = dmsShell.blur.enable;
        blurForegroundLayers = dmsShell.blur.foregroundLayers;
        blurBorderEnabled = dmsShell.blur.borderEnabled;
        blurBorderColor = dmsShell.blur.borderColor;
        blurBorderCustomColor = dmsShell.blur.borderCustomColor;
        blurBorderOpacity = dmsShell.blur.borderOpacity;

        # DEPTH
        m3ElevationEnabled = dmsShell.elevation.enable;
        m3ElevationIntensity = dmsShell.elevation.intensity;
        m3ElevationOpacity = dmsShell.elevation.opacity;
        barElevationEnabled = dmsShell.elevation.bar;
        popoutElevationEnabled = dmsShell.elevation.popout;
        modalElevationEnabled = dmsShell.elevation.modal;

        enableRippleEffects = dmsShell.rippleEffects;
        waveProgressEnabled = dmsShell.waveProgress;

        systemTrayIconTintMode = dmsShell.trayIconTint;
        focusedWindowShowIcon = dmsShell.focusedWindow.showIcon;
        inherit (dmsShell) launcherStyle;

        clockFormat = dmsShell.clock.format;
        clockDateFormat = dmsShell.clock.dateFormat;
        showSeconds = dmsShell.clock.showSeconds;

        lockScreenWallpaperPath = dmsShell.lockWallpaper;

        inherit (dmsShell) controlCenterWidgets;

        # GLASS
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
        appsDockEnlargeOnHover = dmsDock.enlargeOnHover;
        appsDockEnlargePercentage = dmsDock.enlargePercentage;
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
      settingsJson =
        pkgs.runCommand "dms-settings.json"
          {
            nativeBuildInputs = [ pkgs.jq ];
            passAsFile = [
              "keys"
              "widgets"
            ];
            keys = concatStringsSep "\n" (attrNames settings);
            widgets = concatStringsSep "\n" (dmsBar.leftWidgets ++ dmsBar.centerWidgets ++ dmsBar.rightWidgets);
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

            # BAR WIDGETS
            knownWidgets="$(mktemp)"
            grep -oP '^\s*"\K[\w-]+(?=":\s*components\.)' \
              ${inputs.dms}/quickshell/Modules/DankBar/WidgetHost.qml | sort -u > "$knownWidgets"

            unknownWidgets="$({ grep -v ':' "$widgetsPath" || true; } | sort -u | comm -23 - "$knownWidgets")"
            if [ -n "$unknownWidgets" ]; then
              echo "bar widgets not present in this DankMaterialShell:" >&2
              echo "$unknownWidgets" >&2
              exit 1
            fi

            cp ${pkgs.writers.writeJSON "dms-settings-unchecked.json" settings} $out
          '';
    in
    {
      # DMS THEME
      xdg.config.files."DankMaterialShell/dank-theme.json" = {
        generator = pkgs.writers.writeJSON "dms-theme.json";
        value =
          if theme.palettes.dark != null && theme.palettes.light != null then
            {
              dark = roles theme.palettes.dark // {
                name = "${theme.name}-dark";
              };
              light = roles theme.palettes.light // {
                name = "${theme.name}-light";
              };
            }
          else
            roles palette // { inherit (theme) name; };
      };

      xdg.config.files."DankMaterialShell/settings.json".source = settingsJson;
    };
}
