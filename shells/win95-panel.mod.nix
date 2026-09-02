{
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

      inherit (osConfig) theme;
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
        inherit (palette) base;
        inherit (palette) surface;
        inherit (palette) overlay;
        inherit (palette) muted;

        inherit (palette) text;
        inherit (palette) subtext;

        inherit (palette) accent;
        inherit (palette) accentText;

        inherit (palette) red;
        inherit (palette) green;
        inherit (palette) blue;
        inherit (palette) yellow;

        inherit (theme) borderWidth;
        inherit (theme) padding;
        fontSize = theme.font.size.normal;
        fontFamily = theme.font.sans.name;

        # Taskbar icon box. Derived from the big font size so the bar scales
        # with the theme rather than pinning a magic pixel count.
        iconSize = theme.font.size.big;

        # Quick Launch, by desktop-entry id. Anything not installed is
        # filtered out at runtime rather than drawing a broken button.
        quickLaunch = [
          "foot"
          "org.kde.dolphin"
          "helium"
        ];
      };

      tokensJs = pkgs.writeText "Tokens.js" ''
        // Generated from `theme` — see shells/win95-panel.mod.nix.
        // Do not edit; change the theme tokens instead.
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
