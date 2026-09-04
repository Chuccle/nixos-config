{
  desktopModules.qt =
    { lib, ... }:
    let
      inherit (lib.modules) mkForce;
    in
    {
      # QT PLATFORM THEME (system half)
      # Forced at the NixOS level so it lands in /etc/set-environment and wins
      # everywhere: the DMS module exports gtk3 passthrough system-wide, which
      # otherwise overrides the hjem-level value for the whole session.
      environment.sessionVariables.QT_QPA_PLATFORMTHEME = mkForce "qt6ct";
      environment.sessionVariables.QT_QPA_PLATFORMTHEME_QT6 = mkForce "qt6ct";
    };

  desktopHomeModules.qt =
    {
      config,
      lib,
      osConfig,
      pkgs,
      ...
    }:
    let
      inherit (lib.generators) toINI toKeyValue;
      inherit (lib.lists) singleton;
      inherit (lib.strings) concatStringsSep;

      inherit (osConfig) theme;
      inherit (theme) palette;

      # QPalette::ColorRole enum order (Qt6): WindowText, Button, Light,
      # Midlight, Dark, Mid, Text, BrightText, ButtonText, Base, Window,
      # Shadow, Highlight, HighlightedText, Link, LinkVisited, AlternateBase,
      # NoRole, ToolTipBase, ToolTipText, PlaceholderText, Accent.
      mkRow =
        {
          windowText,
          button,
          light,
          midlight,
          dark,
          mid,
          text,
          brightText,
          buttonText,
          base,
          window,
          shadow,
          highlight,
          highlightedText,
          link,
          linkVisited,
          alternateBase,
          noRole,
          toolTipBase,
          toolTipText,
          placeholderText,
          accent,
        }:
        concatStringsSep ", " (
          map ({ argb, ... }: argb) [
            windowText
            button
            light
            midlight
            dark
            mid
            text
            brightText
            buttonText
            base
            window
            shadow
            highlight
            highlightedText
            link
            linkVisited
            alternateBase
            noRole
            toolTipBase
            toolTipText
            placeholderText
            accent
          ]
        );

      # Active: full contrast, tokens map straight across.
      active = mkRow {
        windowText = palette.text;
        button = palette.surface;
        light = palette.overlay;
        midlight = palette.surface;
        dark = palette.base;
        mid = palette.base;
        inherit (palette) text;
        brightText = palette.text;
        buttonText = palette.text;
        base = palette.surface;
        window = palette.base;
        shadow = palette.base;
        highlight = palette.accent;
        highlightedText = palette.accentText;
        link = palette.accent;
        linkVisited = palette.accent;
        alternateBase = palette.overlay;
        noRole = palette.text;
        toolTipBase = palette.overlay;
        toolTipText = palette.text;
        placeholderText = palette.subtext;
        inherit (palette) accent;
      };

      # Inactive: same backgrounds, foreground dimmed to subtext, selection
      # neutralized (unfocused windows shouldn't show the live accent color).
      inactive = mkRow {
        windowText = palette.subtext;
        button = palette.surface;
        light = palette.overlay;
        midlight = palette.surface;
        dark = palette.base;
        mid = palette.base;
        text = palette.subtext;
        brightText = palette.text;
        buttonText = palette.subtext;
        base = palette.surface;
        window = palette.base;
        shadow = palette.base;
        highlight = palette.overlay;
        highlightedText = palette.subtext;
        link = palette.accent;
        linkVisited = palette.accent;
        alternateBase = palette.overlay;
        noRole = palette.text;
        toolTipBase = palette.overlay;
        toolTipText = palette.text;
        placeholderText = palette.subtext;
        accent = palette.surface;
      };

      # Disabled: same backgrounds, foreground reduced further to muted.
      disabled = mkRow {
        windowText = palette.muted;
        button = palette.surface;
        light = palette.overlay;
        midlight = palette.surface;
        dark = palette.base;
        mid = palette.base;
        text = palette.muted;
        brightText = palette.text;
        buttonText = palette.muted;
        base = palette.surface;
        window = palette.base;
        shadow = palette.base;
        highlight = palette.overlay;
        highlightedText = palette.muted;
        link = palette.muted;
        linkVisited = palette.muted;
        alternateBase = palette.overlay;
        noRole = palette.text;
        toolTipBase = palette.overlay;
        toolTipText = palette.muted;
        placeholderText = palette.muted;
        accent = palette.surface;
      };
    in
    {
      # QT PLATFORM THEME (home half)
      # qt6ct lets Qt apps follow our icon theme, widget style, and full
      # color palette on the non-Plasma stacks (Plasma themes Qt itself, so
      # a Plasma host omits this adapter). Without the generated color
      # scheme, Qt apps render in Fusion's generic gray regardless of theme.
      packages = singleton pkgs.kdePackages.qt6ct;

      xdg.config.files."qt6ct/qt6ct.conf" = {
        generator = toINI { };
        value.Appearance = {
          icon_theme = theme.icons.name;
          style = "Fusion";
          standard_dialogs = "default";
          custom_palette = true;
          color_scheme_path = "${config.xdg.config.directory}/qt6ct/colors/${theme.name}.conf";
        };
      };

      xdg.config.files."qt6ct/colors/${theme.name}.conf" = {
        generator = toINI { };
        value.ColorScheme = {
          active_colors = active;
          inactive_colors = inactive;
          disabled_colors = disabled;
        };
      };

      # DMS's session runtime defaults launched apps to gtk3 passthrough; its
      # documented override point is environment.d, and 95- sorts after DMS's
      # own 90-dms.conf so this wins in the systemd user manager too.
      xdg.config.files."environment.d/95-qt6ct.conf" = {
        generator = toKeyValue { };
        value = {
          QT_QPA_PLATFORMTHEME = "qt6ct";
          QT_QPA_PLATFORMTHEME_QT6 = "qt6ct";
        };
      };
    };
}
