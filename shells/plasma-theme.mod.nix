{
  desktopHomeModules.plasma-theme =
    { lib, osConfig, ... }:
    let
      inherit (lib.generators) toINI;

      inherit (osConfig) theme;
      inherit (theme) palette;

      fontSpec = name: "${name},${toString theme.font.size.normal},-1,5,50,0,0,0,0,0";

      colors = bg: fg: {
        BackgroundNormal = bg.rgb;
        ForegroundNormal = fg.rgb;
      };
    in
    {
      # PLASMA COLOR SCHEME
      # Generated from tokens via lib.generators.toINI (matches the repo's
      # generator idiom; the file lands in the store, so treefmt never sees it).
      # KDE may log write failures against the read-only declarative file but
      # reads the values fine.
      xdg.config.files."kdeglobals" = {
        generator = toINI { };
        value = {
          General = {
            ColorScheme = "Tokens";
            Name = "Tokens";
            font = fontSpec theme.font.sans.name;
            fixed = fontSpec theme.font.mono.name;
          };

          "Colors:Window" = colors palette.surface palette.text // {
            BackgroundAlternate = palette.overlay.rgb;
            ForegroundInactive = palette.muted.rgb;
          };

          "Colors:View" = colors palette.base palette.text // {
            BackgroundAlternate = palette.surface.rgb;
            ForegroundInactive = palette.muted.rgb;
          };

          "Colors:Button" = colors palette.surface palette.text // {
            BackgroundAlternate = palette.overlay.rgb;
          };

          "Colors:Selection" = colors palette.accent palette.accentText;
          "Colors:Tooltip" = colors palette.overlay palette.text;
          "Colors:Complementary" = colors palette.base palette.text;
        };
      };

      # KWIN
      # Blur effect tracks the theme's glass toggle.
      xdg.config.files."kwinrc" = {
        generator = toINI { };
        value = {
          Plugins.blurEnabled = theme.blur.enable;
          "Effect-blur".BlurStrength = theme.blur.radius;
        };
      };
    };
}
