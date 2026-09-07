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
      inherit (lib.modules) mkDefault;
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
      # `mkDefault` on the whole attrset is a single definition at one
      # priority: a host that sets one field defines the option at a higher
      # priority, `filterOverrides` then drops the default definition whole,
      # and every field the host did not mention is suddenly unset. Applying
      # it per leaf instead makes each field default on its own, which is what
      # "a host can override any field" has always claimed.
      defaults = mapAttrsRecursive (_path: mkDefault);
    in
    {
      # WIN95 PANEL
      # Style/behaviour tokens for the Quickshell taskbar: panel-specific, so
      # not part of `theme` (which is only the DE-agnostic data every adapter
      # reads), but still a host-overridable declaration rather than a literal
      # baked into the shell. Same shape and rationale as `dmsBar` in
      # shells/dms.mod.nix.
      #
      # Everything here used to be a magic number or a bare string sitting in a
      # .qml file, where nothing checked it and a host could not reach it: the
      # Start label, the menu banner, the popup geometry, the clock format, the
      # Quick Launch list and the power commands. Declared as a typed submodule
      # they are checked on the way in — a menu width given as `"260"`, or a
      # `poweroff` action given as a bare string instead of an argv list, is an
      # eval error rather than a panel that draws wrong or a menu entry that
      # does nothing at 2am.
      options.win95Panel = mkOption {
        description = "Win95 Quickshell taskbar style/behaviour tokens.";
        type = submodule {
          options = {
            startLabel = mkOption { type = nonEmptyStr; };
            bannerText = mkOption { type = nonEmptyStr; };

            # Qt.formatDateTime pattern, not strftime — `AP` is the AM/PM
            # marker, `h` the 12-hour clock.
            clockFormat = mkOption { type = nonEmptyStr; };

            # Quick Launch, by desktop-entry id. Anything not installed is
            # filtered out at runtime rather than drawing a broken button.
            quickLaunch = mkOption { type = listOf nonEmptyStr; };

            iconSize = mkOption { type = unsigned; };
            taskButtonWidth = mkOption { type = unsigned; };

            menuWidth = mkOption { type = unsigned; };
            menuHeight = mkOption { type = unsigned; };

            # argv, not a shell line: Quickshell's Process takes a command
            # list, and the panel inherits greetd's environment rather than a
            # login shell's PATH, so these have to be absolute.
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
          "foot"
          "org.kde.dolphin"
          "helium"
        ];

        # Derived from the big font size so the bar scales with the theme
        # rather than pinning a magic pixel count.
        iconSize = theme.font.size.big;

        # A Win95 task button stops growing at roughly a third of a 640-wide
        # screen; past that the title is elided instead.
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
      inherit (lib.strings) concatStringsSep;

      inherit (osConfig) theme win95Panel;
      inherit (theme) palette;

      # DESIGN TOKENS -> QML
      # The only generated file in the shell. Everything else in ./win95 is a
      # real .qml file that an editor and qmllint both understand; this is the
      # single seam where Nix data crosses into QML.
      #
      # A `.pragma library` JS module rather than a QML singleton: it needs no
      # qmldir registration, so it cannot collide with the one Quickshell
      # generates for the config directory.
      tokens = {
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

      tokensJs = pkgs.writeText "Tokens.js" ''
        // Generated from `theme` and `win95Panel` — see shells/win95-panel.mod.nix.
        // Do not edit; change the tokens instead.
        .pragma library

        ${concatStringsSep "\n" (mapAttrsToList (name: value: "var ${name} = ${toJSON { } value};") tokens)}
      '';

      # BUILD-TIME VALIDATION
      # qmllint resolves against Qt's and Quickshell's shipped .qmltypes, so a
      # bad import, a property that does not exist, or an unqualified
      # identifier fails the build rather than producing a broken panel at
      # login. The categories below are escalated from warnings to errors —
      # qmllint exits 0 on warnings by default, so without this the check
      # would pass on almost anything.
      #
      # `uncreatable-type` and `unused-imports` stay warnings: Quickshell
      # registers PanelWindow through an interface the linter reads as
      # non-constructible, and neither indicates a real fault.
      shell = pkgs.runCommand "win95-shell" { nativeBuildInputs = [ pkgs.kdePackages.qtdeclarative ]; } ''
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
      # A Quickshell panel with real two-tone 3D chrome: `Bevel` draws light
      # top/left + dark bottom/right edges (raised) or the reverse (sunken),
      # thickness from `theme.borderWidth`. Loaded via `quickshell -c win95`
      # from the labwc autostart.
      xdg.config.files."quickshell/win95".source = shell;
    };
}
