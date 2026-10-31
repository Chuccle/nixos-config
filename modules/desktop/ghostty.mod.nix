{
  flake.homeModules.desktop-ghostty =
    { lib, pkgs, ... }:
    let
      inherit (lib.meta) getExe;
    in
    {
      config.programs.ghostty = {
        enable = true;

        settings = {
          command = getExe pkgs.nushell;

          font-family = "DejaVu Sans Mono";
          font-size = 12;
          background = "080808";
          foreground = "e4e2e3";
          background-opacity = 0.72;
          cursor-color = "ffffff";
          selection-background = "444444";
          selection-foreground = "ffffff";
          window-decoration = "none";
          window-padding-x = 14;
          window-padding-y = 14;
          confirm-close-surface = false;
        };
      };
    };
}
