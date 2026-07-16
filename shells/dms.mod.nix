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
            for _ in $(seq 30); do
              if dms ipc call wallpaper set ${theme.wallpaper}; then
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
      osConfig,
      pkgs,
      ...
    }:
    let
      inherit (osConfig) dmsBar theme;
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

      # DMS owns this file's schema; only keys confirmed present in the pinned
      # DMS's persisted settings go here (hjem replaces the file on rebuild, so
      # UI tweaks to these do not persist). GLASS: every surface tracks one
      # token for a consistent look. blurEnabled + blurForegroundLayers are the
      # real blur switches in this DMS version; popup/dock and the bar's
      # transparency/widgetTransparency then set the surface opacity uniformly.
      # frame* are a newer master-only feature (inert here) kept for forward
      # compatibility. Flat themes leave blur.enable false, so opacity stays 1.0
      # and everything is opaque.
      xdg.config.files."DankMaterialShell/settings.json" = {
        generator = pkgs.writers.writeJSON "dms-settings.json";
        value = {
          currentThemeName = "custom";
          customThemeFile = themeFile;

          blurEnabled = theme.blur.enable;
          blurForegroundLayers = theme.blur.enable;

          frameEnabled = theme.blur.enable;
          frameBlurEnabled = theme.blur.enable;
          frameOpacity = theme.blur.opacity;

          popupTransparency = theme.blur.opacity;
          dockTransparency = theme.blur.opacity;

          barConfigs = [ barConfig ];
        };
      };
    };
}
