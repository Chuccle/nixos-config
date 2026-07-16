{
  flake.homeModules.foot =
    { lib, osConfig, ... }:
    let
      inherit (lib.strings) removePrefix;

      inherit (osConfig) theme;
      inherit (theme) palette;

      hex = removePrefix "#";
      glass = theme.blur.enable;
    in
    {
      # hjem-rum's own `foot` program module (same as zoxide.mod.nix already
      # does) generates the ini via pkgs.formats.ini and installs the package,
      # so no manual `packages`/`xdg.config.files` here. A bare `enable = true`
      # on the plain hjem `packages`-less module previously set hjem's
      # per-user flag instead of installing anything — this path avoids that
      # trap entirely.
      programs.foot = {
        enable = true;
        settings = {
          main = {
            font = "${theme.font.mono.name}:size=${toString theme.font.size.normal}";
            pad = "${toString theme.padding}x${toString theme.padding}";
          };

          "colors-dark" = {
            # `surface`, not `base` — `base` is the desktop backdrop tone
            # (win95's is the literal teal wallpaper color), so using it here
            # made the terminal window blend into the desktop behind it.
            background = hex palette.surface;
            foreground = hex palette.text;

            regular0 = hex palette.surface;
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
