{
  desktopModules.qt =
    {
      config,
      lib,
      pkgs,
      ...
    }:
    let
      inherit (lib.lists) singleton;
      inherit (lib.modules) mkForce;
    in
    {
      environment.sessionVariables.QT_QPA_PLATFORMTHEME = mkForce "qt6ct";
      environment.sessionVariables.QT_QPA_PLATFORMTHEME_QT6 = mkForce "qt6ct";

      # QT WINDOW DECORATIONS
      environment.systemPackages = singleton pkgs.qadwaitadecorations-qt6;
      environment.sessionVariables.QT_WAYLAND_DECORATION =
        if config.theme.cornerRadius == 0 then "bradient" else "adwaita";
      environment.sessionVariables.QT_PLUGIN_PATH = singleton "${pkgs.qadwaitadecorations-qt6}/${pkgs.qt6.qtbase.qtPluginPrefix}";
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

      sunken = if theme.appearance == "dark" then palette.base else palette.muted;

      # Argument order matches Qt6 QPalette::ColorRole.
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
        dark = sunken;
        mid = sunken;
        inherit (palette) text;
        brightText = palette.text;
        buttonText = palette.text;
        base = palette.surface;
        window = palette.surface;
        shadow = sunken;
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

      inactive = mkRow {
        windowText = palette.subtext;
        button = palette.surface;
        light = palette.overlay;
        midlight = palette.surface;
        dark = sunken;
        mid = sunken;
        text = palette.subtext;
        brightText = palette.text;
        buttonText = palette.subtext;
        base = palette.surface;
        window = palette.surface;
        shadow = sunken;
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
        dark = sunken;
        mid = sunken;
        text = palette.muted;
        brightText = palette.text;
        buttonText = palette.muted;
        base = palette.surface;
        window = palette.surface;
        shadow = sunken;
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

      xdg.config.files."environment.d/95-qt6ct.conf" = {
        generator = toKeyValue { };
        value = {
          QT_QPA_PLATFORMTHEME = "qt6ct";
          QT_QPA_PLATFORMTHEME_QT6 = "qt6ct";
        };
      };
    };
}
