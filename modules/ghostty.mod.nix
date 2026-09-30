{
  flake.homeModules.ghostty =
    {
      config,
      lib,
      osConfig,
      ...
    }:
    let
      inherit (lib.attrsets) filterAttrs mapAttrs;
      inherit (lib.lists) imap0;
      inherit (osConfig) theme;

      colorsFor = name: palette: {
        background = palette.surface.hex;
        foreground = palette.text.hex;
        cursor-color = palette.text.hex;
        cursor-text = palette.surface.hex;
        selection-background = palette.accent.hex;
        selection-foreground = palette.accentText.hex;
        palette = imap0 (index: color: "${toString index}=${color.hex}") [
          (if name == "desktop-dark" then palette.surface else palette.text)
          palette.red
          palette.green
          palette.yellow
          palette.blue
          palette.accent
          palette.blue
          palette.subtext
          palette.muted
          palette.red
          palette.green
          palette.yellow
          palette.blue
          palette.accent
          palette.blue
          palette.text
        ];
      };
    in
    {
      programs.ghostty = {
        enable = true;
        settings = {
          theme = "desktop-${theme.appearance}";
          config-file = "?${config.directory}/.local/state/ghostty/appearance";
          font-family = theme.font.mono.name;
          font-size = theme.font.size.normal;
          background-opacity = if theme.blur.enable then theme.blur.opacity else 1.0;
          window-padding-x = theme.padding;
          window-padding-y = theme.padding;
          gtk-titlebar = true;
          gtk-titlebar-style = "native";
          gtk-single-instance = false;
          quit-after-last-window-closed = true;
        };
        themes =
          mapAttrs colorsFor
          <| filterAttrs (_: palette: palette != null) {
            desktop-dark = theme.palettes.dark;
            desktop-light = theme.palettes.light;
          };
      };
    };
}
