{ inputs, ... }:
{
  # DANKMATERIALSHELL (Tahoe / liquid glass)
  # DMS's home option is a home-manager module, which this repo does not use, so
  # we take its NixOS module instead (installs the shell to /etc/xdg/quickshell
  # + the `dms` CLI). Pure: only composed into hosts that want it.
  desktopModules.dms = {
    imports = [ inputs.dms.nixosModules.dank-material-shell ];

    # Autostart via DMS's own user service (bound to graphical-session.target,
    # which niri provides) so the bar does not depend on `dms` being on PATH.
    # Static palette comes from tokens, so disable wallpaper-driven theming.
    programs.dank-material-shell.enable = true;
    programs.dank-material-shell.systemd.enable = true;
    programs.dank-material-shell.enableDynamicTheming = false;
  };

  desktopHomeModules.dms =
    { osConfig, pkgs, ... }:
    let
      inherit (osConfig.theme) palette blur;
    in
    {
      # DMS USER SETTINGS
      # Static palette from tokens for reproducibility. NOTE: DMS's settings.json
      # schema should be confirmed against a running instance — key names here are
      # best-effort and ignored keys are harmless.
      #
      # LIQUID GLASS: niri exposes ext-bg-effect-v1, so blur needs no
      # compositor-side config — just DMS's own toggle, tracking the theme's
      # blur tokens (blur.opacity is a string token; fromJSON turns "0.6" into
      # the number DMS expects).
      xdg.config.files."DankMaterialShell/settings.json" = {
        generator = pkgs.writers.writeJSON "dms-settings.json";
        value = {
          theme = "dark";
          dynamicTheming = false;
          surfaceStyle = "aurora";

          backgroundBlur = blur.enable;
          blurRadius = blur.radius;
          widgetTransparency = blur.enable;
          surfaceOpacity = builtins.fromJSON blur.opacity;

          customColors = {
            primary = palette.accent;
            background = palette.base;
            inherit (palette) surface;
            surfaceVariant = palette.overlay;
            inherit (palette) text;
            inherit (palette) subtext;
            error = palette.red;
          };
        };
      };
    };
}
