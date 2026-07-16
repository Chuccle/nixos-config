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
      inherit (lib.modules) mkIf;
    in
    {
      imports = [ inputs.dms.nixosModules.dank-material-shell ];

      # Autostart via DMS's own user service (bound to graphical-session.target,
      # which niri-session provides) so the bar does not depend on `dms` being on
      # PATH. Static palette comes from tokens, so disable wallpaper-driven
      # theming.
      programs.dank-material-shell.enable = true;
      programs.dank-material-shell.systemd.enable = true;
      programs.dank-material-shell.enableDynamicTheming = false;

      # WALLPAPER
      # DMS draws its own wallpaper layer (covering swaybg and friends), and its
      # documented interface for it is IPC: `dms ipc call wallpaper set <path>`.
      # The shell's socket comes up asynchronously, so retry until it accepts.
      # User units do not get the system profile on PATH, so the retry loop's
      # deps are provided explicitly: `dms` itself, coreutils, and quickshell —
      # `dms ipc` shells out to `qs`, so without it the call dies with
      # `exec: "qs": … $PATH`.
      systemd.user.services.dms-wallpaper = mkIf (config.theme.wallpaper != null) {
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
            if dms ipc call wallpaper set ${config.theme.wallpaper}; then
              exit 0
            fi
            sleep 1
          done
          exit 1
        '';
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
      inherit (osConfig) theme;
      inherit (theme) blur palette;

      themeFile = "${config.directory}/.config/DankMaterialShell/dank-theme.json";

      # Default "Main Bar", captured verbatim from a running instance of the
      # pinned DMS (its persisted barConfigs[0]) so it round-trips exactly for
      # this version. DMS reads barConfigs as a whole, so the entire object is
      # provided — which pins the widget layout to this default; recapture if
      # you rearrange the bar in the DMS UI. Only the two translucency fields
      # are token-driven.
      barConfig = {
        id = "default";
        name = "Main Bar";
        enabled = true;
        position = 0;
        screenPreferences = [ "all" ];
        showOnLastDisplay = true;
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
        transparency = blur.opacity;
        widgetTransparency = blur.opacity;

        squareCorners = false;
        noBackground = false;
        gothCornersEnabled = false;
        gothCornerRadiusOverride = false;
        gothCornerRadiusValue = 12;
        borderEnabled = false;
        borderColor = "surfaceText";
        borderOpacity = 1;
        borderThickness = 1;
        fontScale = 1;
        autoHide = false;
        autoHideDelay = 250;
        openOnOverview = false;
        visible = true;
        popupGapsAuto = true;
        popupGapsManual = 4;
        widgetOutlineEnabled = false;
        shadowIntensity = 0;
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

          blurEnabled = blur.enable;
          blurForegroundLayers = blur.enable;

          frameEnabled = blur.enable;
          frameBlurEnabled = blur.enable;
          frameOpacity = blur.opacity;

          popupTransparency = blur.opacity;
          dockTransparency = blur.opacity;

          barConfigs = [ barConfig ];
        };
      };
    };
}
