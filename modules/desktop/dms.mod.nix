{ inputs, lib, ... }:
let
  inherit (lib.lists) singleton;
in
{
  flake.nixosModules.desktop-dms = {
    imports = singleton inputs.dms.nixosModules.default;

    config = {
      security.pam.services.dankshell = { };

      services.upower.enable = true;

      programs.dank-material-shell = {
        enable = true;
        systemd.enable = true;
        enableDynamicTheming = false;
        enableCalendarEvents = false;
      };
    };
  };

  flake.homeModules.desktop-dms =
    {
      config,
      lib,
      osConfig,
      pkgs,
      ...
    }:
    let
      inherit (lib.attrsets) attrNames optionalAttrs;
      inherit (lib.lists) elem optional;
      inherit (lib.meta) getExe;

      outputs = attrNames <| osConfig.programs.niri.settings.outputs or { };
    in
    {
      config = {
        xdg.config.files."DankMaterialShell/settings.json" = {
          type = "copy";
          generator = (pkgs.formats.json { }).generate "dms-settings.json";
          value = {
            currentThemeName = "monochrome";
            fontFamily = "DejaVu Sans";
            monoFontFamily = "DejaVu Sans Mono";
            fontScale = 0.9;

            radiusMode = "fixed";
            fixedRadius = 20;
            popupTransparency = 1.0;
            blurBorderEnabled = false;

            hostSurfaceColor = "custom";
            hostSurfaceCustomColor = "#000000";
            cardSurfaceColor = "custom";
            cardSurfaceCustomColor = "#080808";
            chipSurfaceColor = "custom";
            chipSurfaceCustomColor = "#080808";
            widgetBackgroundColor = "custom";
            widgetBackgroundCustomColor = "#000000";
            widgetBackgroundCustomStrength = 1.0;

            clockFormat = "24h";
            clockDateFormat = "ddd MMM d";
            showSeconds = false;

            dashCards = [
              {
                id = "clock";
                col = 0;
                row = 0;
                w = 1;
                h = 2;
              }
              {
                id = "sysmon";
                col = 0;
                row = 2;
                w = 1;
                h = 2;
              }
              {
                id = "weather";
                col = 1;
                row = 0;
                w = 2;
                h = 1;
              }
              {
                id = "user";
                col = 3;
                row = 0;
                w = 2;
                h = 1;
              }
              {
                id = "calendar";
                col = 1;
                row = 1;
                w = 3;
                h = 3;
              }
              {
                id = "media";
                col = 4;
                row = 1;
                w = 1;
                h = 3;
              }
            ];

            dashOptions = {
              overview = {
                panelColumns = 5;
                panelRows = 4;
              };

              clock = {
                date = true;
                tone = "";
              };

              media.artStyle = "circle";
            };

            barConfigs =
              (if outputs == [ ] then singleton "all" else outputs)
              |> map (
                name:
                let
                  portrait = elem (osConfig.programs.niri.settings.outputs.${name}.transform.rotation or 0) [
                    90
                    270
                  ];
                in
                {
                  id = name;
                  inherit name;
                  enabled = true;
                  island = true;
                  position = 0;
                  screenPreferences = singleton name;

                  leftWidgets = [
                    {
                      id = "launcherButton";
                      launcherLogoMode = "compositor";
                      launcherLogoColorOverride = "#ffffff";
                    }
                    {
                      id = "workspaceSwitcher";
                      workspaceIndicatorStyle = "pills";
                      showWorkspaceIndex = false;
                      showWorkspaceName = false;
                      showWorkspaceApps = false;
                      showOccupiedWorkspacesOnly = false;
                      workspaceColorMode = "custom";
                      workspaceFocusedCustomColor = "#ffffff";
                      workspaceUnfocusedColorMode = "custom";
                      workspaceUnfocusedCustomColor = "#555555";
                    }
                  ]
                  ++ optional (!portrait) "focusedWindow";

                  centerWidgets = [ ];

                  islandCompactThickness = 40;
                  islandInteractionMode = "click";
                  islandSystemOsd = true;
                  islandNotificationPopups = false;
                  islandMediaClockVisible = true;
                  islandHomeClockDisplay = "both";
                  islandRouteDash = "island";
                  islandRouteMedia = "island";
                  islandRouteNotificationCenter = "island";

                  rightWidgets = [
                    "notificationButton"
                    "notepadButton"
                    "clipboard"
                    "diskUsage"
                    {
                      id = "memUsage";
                      showInGb = true;
                      showSwap = false;
                    }
                    "cpuUsage"
                    "network_speed_monitor"
                    "controlCenterButton"
                    "systemTray"
                  ];

                  widgetStyle = "pills";
                  spacing = 4;
                  innerPadding = 12;
                  widgetPadding = 8;
                  barInsetPadding = 12;
                  bottomGap = 6;
                  attachToScreenEdge = false;
                  noBackground = false;
                  squareCorners = false;
                  borderEnabled = false;
                  widgetOutlineEnabled = false;
                  followInterfaceStyle = false;
                  transparency = 1.0;
                  widgetFollowInterfaceStyle = false;
                  widgetTransparency = 1.0;
                  fontScale = 1.1;
                  iconScale = 1.1;
                  maximizeWidgetText = !portrait;
                  maximizeWidgetIcons = !portrait;

                  autoHide = false;
                  scrollEnabled = true;
                  scrollXBehavior = "column";
                  scrollYBehavior = "workspace";
                }
                // optionalAttrs portrait {
                  island = false;
                  rightWidgets = [ ];
                  innerPadding = 2;
                  widgetPadding = 6;
                  barInsetPadding = 4;
                  fontScale = 0.95;
                  iconScale = 1.0;
                  transparency = 0.0;
                  clickThrough = true;
                }
              );
          };
        };

        xdg.state.files."DankMaterialShell/session.json" = {
          type = "copy";
          generator = (pkgs.formats.json { }).generate "dms-session.json";
          value = {
            isLightMode = false;
            terminalOverride = getExe config.programs.ghostty.package;
          };
        };
      };
    };
}
