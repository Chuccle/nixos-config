{
  desktopHomeModules.qt =
    { lib, pkgs, ... }:
    let
      inherit (lib.lists) singleton;
    in
    {
      # QT PLATFORM THEME
      # qt6ct lets Qt apps follow our icon theme and fonts on the non-Plasma
      # stacks (Plasma themes Qt itself, so a Plasma host omits this adapter).
      # Fine-grained Qt colour mapping from tokens is a follow-up.
      environment.sessionVariables.QT_QPA_PLATFORMTHEME = "qt6ct";

      packages = singleton pkgs.kdePackages.qt6ct;
    };
}
