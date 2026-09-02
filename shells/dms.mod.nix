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
      inherit (lib.modules) mkDefault mkIf;
      inherit (lib.options) mkOption;
      inherit (lib.types)
        bool
        float
        int
        listOf
        str
        submodule
        ;

      inherit (config) theme;
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

            spacing = mkOption { type = int; };
            innerPadding = mkOption { type = int; };
            bottomGap = mkOption { type = int; };

            transparency = mkOption { type = float; };
            widgetTransparency = mkOption { type = float; };

            squareCorners = mkOption { type = bool; };
            noBackground = mkOption { type = bool; };
            gothCornersEnabled = mkOption { type = bool; };
            gothCornerRadiusOverride = mkOption { type = bool; };
            gothCornerRadiusValue = mkOption { type = int; };

            borderEnabled = mkOption { type = bool; };
            borderColor = mkOption { type = str; };
            borderOpacity = mkOption { type = float; };
            borderThickness = mkOption { type = int; };

            fontScale = mkOption { type = float; };

            autoHide = mkOption { type = bool; };
            autoHideDelay = mkOption { type = int; };
            openOnOverview = mkOption { type = bool; };
            visible = mkOption { type = bool; };

            popupGapsAuto = mkOption { type = bool; };
            popupGapsManual = mkOption { type = int; };

            widgetOutlineEnabled = mkOption { type = bool; };
            shadowIntensity = mkOption { type = int; };
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

            position = mkOption { type = int; };
            iconSize = mkOption { type = int; };
            spacing = mkOption { type = int; };
            bottomGap = mkOption { type = int; };
            margin = mkOption { type = int; };

            transparency = mkOption { type = float; };
            indicatorStyle = mkOption { type = str; };

            borderEnabled = mkOption { type = bool; };
            borderColor = mkOption { type = str; };
            borderOpacity = mkOption { type = float; };
            borderThickness = mkOption { type = int; };

            launcherEnabled = mkOption { type = bool; };
          };
        };
      };

      config = {
        dmsBar = mkDefault {
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
        dmsDock = mkDefault {
          show = theme.blur.enable;
          autoHide = true;
          smartAutoHide = true;
          openOnOverview = true;
          groupByApp = true;

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

      inherit (osConfig) dmsBar dmsDock theme;
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

        blurEnabled = theme.blur.enable;
        blurForegroundLayers = theme.blur.enable;

        # GLASS
        # `frame*` draws DMS's rounded screen-edge frame — the detail that
        # makes the whole session read as one continuous pane of glass rather
        # than a bar floating over a wallpaper.
        frameEnabled = theme.blur.enable;
        frameBlurEnabled = theme.blur.enable;
        frameOpacity = theme.blur.opacity;
        frameRounding = theme.cornerRadius;
        frameThickness = theme.margin * 2;
        frameCloseGaps = true;

        popupTransparency = theme.blur.opacity;
        dockTransparency = dmsDock.transparency;

        showDock = dmsDock.show;
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

          primary = palette.accent;
          primaryText = palette.accentText;
          primaryContainer = palette.overlay;
          secondary = palette.blue;

          inherit (palette) surface;
          surfaceText = palette.text;
          surfaceVariant = palette.overlay;
          surfaceVariantText = palette.subtext;
          surfaceTint = palette.accent;

          background = palette.base;
          backgroundText = palette.text;
          outline = palette.muted;

          surfaceContainer = palette.surface;
          surfaceContainerHigh = palette.overlay;
          surfaceContainerHighest = palette.overlay;

          error = palette.red;
          warning = palette.yellow;
          info = palette.blue;
        };
      };

      # hjem replaces this file on every rebuild, so anything tweaked in the
      # DMS settings UI is lost — the tokens above are the source of truth.
      xdg.config.files."DankMaterialShell/settings.json".source = settingsJson;
    };
}
