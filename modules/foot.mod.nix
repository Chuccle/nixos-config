{
  flake.homeModules.foot =
    {
      lib,
      osConfig,
      pkgs,
      ...
    }:
    let
      inherit (lib.generators) toINI;
      inherit (lib.lists) singleton;
      inherit (lib.strings) removePrefix;

      inherit (osConfig) theme;
      inherit (theme) palette;

      hex = removePrefix "#";
      glass = theme.blur.enable;
    in
    {
      # A bare `enable = true` here set hjem's per-user flag, not foot, so no
      # terminal was ever installed. Install it explicitly for the compositor
      # spawn binds.
      packages = singleton pkgs.foot;

      xdg.config.files."foot/foot.ini" = {
        generator = toINI { };
        value = {
          main = {
            font = "${theme.font.mono.name}:size=${toString theme.font.size.normal}";
            pad = "${toString theme.padding}x${toString theme.padding}";
          };

          colors = {
            background = hex palette.base;
            foreground = hex palette.text;

            regular0 = hex palette.base;
            regular1 = hex palette.red;
            regular2 = hex palette.green;
            regular3 = hex palette.yellow;
            regular4 = hex palette.blue;
            regular5 = hex palette.accent;
            regular6 = hex palette.blue;
            regular7 = hex palette.subtext;

            bright0 = hex palette.muted;
            bright1 = hex palette.red;
            bright2 = hex palette.green;
            bright3 = hex palette.yellow;
            bright4 = hex palette.blue;
            bright5 = hex palette.accent;
            bright6 = hex palette.blue;
            bright7 = hex palette.text;

            "selection-foreground" = hex palette.accentText;
            "selection-background" = hex palette.accent;

            # GLASS: same opacity token the shell popups/dock use, so the
            # terminal's translucency matches. Flat themes (blur.enable =
            # false) stay fully opaque, so niri's compositor-level
            # blur-behind is never visible through it either.
            alpha = builtins.toJSON (if glass then theme.blur.opacity else 1.0);
          };
        };
      };
    };
}
