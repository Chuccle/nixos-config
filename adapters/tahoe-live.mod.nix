{ self, ... }:
{
  # TAHOE LIVE APPLICATIONS
  desktopHomeModules.tahoe-live =
    {
      lib,
      osConfig,
      pkgs,
      ...
    }:
    let
      inherit (lib.lists) singleton;
      inherit (lib.meta) getExe';
      inherit (lib.modules) mkForce;

      ida = self.packages.${osConfig.nixpkgs.hostPlatform.system}.ida-pro;
      launcher = pkgs.writeShellScriptBin "ida" /* bash */ ''
        unset QT_PLUGIN_PATH QT_QPA_PLATFORMTHEME QT_QPA_PLATFORMTHEME_QT6 QT_WAYLAND_DECORATION
        export QT_STYLE_OVERRIDE=fusion
        exec ${getExe' ida "ida"} "$@"
      '';
      desktopItem = pkgs.makeDesktopItem {
        # Match the Wayland app_id recorded in the failed dock capture.
        name = "com.hex_rays.IDA.pro._9_4";
        desktopName = "IDA Pro";
        genericName = "Interactive Disassembler";
        exec = getExe' launcher "ida";
        icon = ../packages/ida-pro/ida-pro.png;
        categories = singleton "Development";
        startupWMClass = "com.hex_rays.IDA.pro._9_4";
      };
      hiddenLegacyEntry = pkgs.makeDesktopItem {
        name = "IDA Pro";
        desktopName = "IDA Pro";
        exec = getExe' ida "ida";
        extraConfig.Hidden = "true";
      };
    in
    {
      # IDA USER THEME
      files.".idapro/themes/default/user.css".source = ../themes/tahoe/ida.qss;

      ida-pro.package =
        mkForce
        <| pkgs.symlinkJoin {
          name = "ida-pro-tahoe-live";
          paths = [
            launcher
            desktopItem
            hiddenLegacyEntry
            ida
          ];
        };
    };
}
