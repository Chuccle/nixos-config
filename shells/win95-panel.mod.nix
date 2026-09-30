{ self, ... }:
{
  desktopModules.win95-panel =
    {
      config,
      lib,
      pkgs,
      ...
    }:
    let
      inherit (lib.attrsets) mapAttrsRecursive;
      inherit (lib.meta) getExe';
      inherit (lib.modules) mkDefault mkForce;
      inherit (lib.options) mkOption;
      inherit (lib.types)
        listOf
        nonEmptyStr
        submodule
        ;
      inherit (lib.types.ints) unsigned;

      inherit (config) theme;

      systemctl = getExe' pkgs.systemd "systemctl";

      # PER-LEAF DEFAULTS
      defaults = mapAttrsRecursive (_path: mkDefault);
    in
    {
      # WIN95 PANEL
      options.win95Panel = mkOption {
        description = "Win95 Quickshell taskbar style/behaviour tokens.";
        type = submodule {
          options = {
            startLabel = mkOption { type = nonEmptyStr; };
            bannerText = mkOption { type = nonEmptyStr; };

            clockFormat = mkOption { type = nonEmptyStr; };

            quickLaunch = mkOption { type = listOf nonEmptyStr; };

            iconSize = mkOption { type = unsigned; };
            taskButtonWidth = mkOption { type = unsigned; };

            menuWidth = mkOption { type = unsigned; };
            menuHeight = mkOption { type = unsigned; };

            power.shutdown = mkOption { type = listOf nonEmptyStr; };
            power.restart = mkOption { type = listOf nonEmptyStr; };
          };
        };
      };

      config.win95Panel = defaults {
        startLabel = "Start";
        bannerText = "Windows 95";

        clockFormat = "h:mm AP";

        quickLaunch = [
          "com.mitchellh.ghostty"
          "org.kde.dolphin"
          "helium"
        ];

        iconSize = theme.font.size.big;

        taskButtonWidth = 200;

        menuWidth = 260;
        menuHeight = 480;

        power.shutdown = [
          systemctl
          "poweroff"
        ];
        power.restart = [
          systemctl
          "reboot"
        ];
      };

      config.niriSession = {
        shell = "win95";
        workspaces = [
          "desktop"
          "parked"
        ];
        shortcuts = [
          {
            key = "Alt+F4";
            action = "close-window";
          }
          {
            key = "Alt+Tab";
            action = "focus-window-previous";
          }
          {
            key = "Mod+E";
            action = "spawn";
            command = [ "dolphin" ];
          }
          {
            key = "Mod+D";
            action = "spawn";
            command = [
              "win95-window-action"
              "show-desktop"
            ];
          }
          {
            key = "Alt+M";
            action = "spawn";
            command = [
              "win95-window-action"
              "hide"
            ];
          }
          {
            key = "Mod+M";
            action = "maximize-window-to-edges";
          }
        ];
      };

      config.niriWindows = {
        floating = true;
        clientDecorations = true;
      };

      config.niriAnimationSlowdown = 0.12;

      config.environment.systemPackages = [
        pkgs.quickshell
        self.packages.${pkgs.stdenv.hostPlatform.system}.win95-window-action
      ];

      config.systemd.user.services.win95-shell = {
        description = "Win95 Quickshell desktop";
        wantedBy = [ "graphical-session.target" ];
        partOf = [ "graphical-session.target" ];
        after = [ "graphical-session.target" ];
        # DesktopEntry commands also need the live user's application profile.
        environment.PATH = mkForce "/etc/profiles/per-user/%u/bin:/run/current-system/sw/bin";
        environment.QSG_RENDER_LOOP = "basic";
        serviceConfig = {
          ExecStart = "${getExe' pkgs.quickshell "quickshell"} -c win95";
          Restart = "on-failure";
          RestartSec = 1;
        };
      };

      config.systemd.user.services.win95-wallpaper = {
        description = "Win95 teal desktop";
        wantedBy = [ "graphical-session.target" ];
        partOf = [ "graphical-session.target" ];
        after = [ "graphical-session.target" ];
        serviceConfig.ExecStart = "${getExe' pkgs.swaybg "swaybg"} -c ${theme.palette.base.hex}";
      };
    };

  desktopHomeModules.win95-panel =
    {
      lib,
      osConfig,
      pkgs,
      ...
    }:
    let
      inherit (lib.attrsets) mapAttrsToList;
      inherit (lib.generators) toJSON;
      inherit (lib.meta) getExe getExe';
      inherit (lib.strings) concatStringsSep;

      inherit (osConfig) theme win95Panel;
      inherit (theme) palette;

      tokens = {
        niriCommand = getExe' osConfig.programs.niri.package "niri";
        windowCommand = getExe self.packages.${pkgs.stdenv.hostPlatform.system}.win95-window-action;
        base = palette.base.hex;
        surface = palette.surface.hex;
        overlay = palette.overlay.hex;
        muted = palette.muted.hex;

        text = palette.text.hex;
        subtext = palette.subtext.hex;

        accent = palette.accent.hex;
        accentText = palette.accentText.hex;

        red = palette.red.hex;
        green = palette.green.hex;
        blue = palette.blue.hex;
        yellow = palette.yellow.hex;

        # The outer half of every bevel — see Bevel.qml.
        edgeLight = palette.edgeLight.hex;
        edgeShade = palette.edgeShade.hex;

        inherit (theme) borderWidth padding;
        fontSize = theme.font.size.normal;
        fontFamily = theme.font.sans.name;

        inherit (win95Panel)
          bannerText
          clockFormat
          iconSize
          menuHeight
          menuWidth
          quickLaunch
          startLabel
          taskButtonWidth
          ;

        powerShutdown = win95Panel.power.shutdown;
        powerRestart = win95Panel.power.restart;
      };

      tokensJs = pkgs.writeText "Tokens.js" /* js */ ''
        // Generated from `theme` and `win95Panel` — see shells/win95-panel.mod.nix.
        // Do not edit; change the tokens instead.
        .pragma library

        ${concatStringsSep "\n" (mapAttrsToList (name: value: "var ${name} = ${toJSON { } value};") tokens)}
      '';

      # BUILD-TIME VALIDATION
      shell =
        pkgs.runCommand "win95-shell" { nativeBuildInputs = [ pkgs.kdePackages.qtdeclarative ]; }
          /* bash */ ''
            mkdir -p $out
            cp ${./win95}/*.qml $out/
            cp ${tokensJs} $out/Tokens.js

            qmllint \
              -I ${pkgs.kdePackages.qtdeclarative}/lib/qt-6/qml \
              -I ${pkgs.quickshell}/lib/qt-6/qml \
              --unqualified error \
              --import error \
              --missing-property error \
              --unresolved-type error \
              --incompatible-type error \
              $out/*.qml
          '';
    in
    {
      # WIN95 TASKBAR
      xdg.config.files."quickshell/win95".source = shell;
    };
}
