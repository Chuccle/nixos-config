{
  flake.homeModules.foot =
    { osConfig, ... }:
    let
      inherit (osConfig) theme;
      inherit (theme) palette;

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
            background = palette.surface.bare;
            foreground = palette.text.bare;

            regular0 = palette.surface.bare;
            regular1 = palette.red.bare;
            regular2 = palette.green.bare;
            regular3 = palette.yellow.bare;
            regular4 = palette.blue.bare;
            regular5 = palette.accent.bare;
            regular6 = palette.blue.bare;
            regular7 = palette.subtext.bare;

            bright0 = palette.muted.bare;
            bright1 = palette.red.bare;
            bright2 = palette.green.bare;
            bright3 = palette.yellow.bare;
            bright4 = palette.blue.bare;
            bright5 = palette.accent.bare;
            bright6 = palette.blue.bare;
            bright7 = palette.text.bare;

            "selection-foreground" = palette.accentText.bare;
            "selection-background" = palette.accent.bare;

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
