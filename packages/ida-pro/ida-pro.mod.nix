{ self, ... }:
{
  flake.homeModules.ida-pro =
    { lib, osConfig, ... }:
    let
      inherit (lib.lists) singleton;
    in
    {
      config = {
        packages = singleton self.packages.${osConfig.nixpkgs.hostPlatform.system}.ida-pro;

        files.".idapro/themes/default/theme.css".source = "${
          self.packages.${osConfig.nixpkgs.hostPlatform.system}.ida-pro-theme
        }/theme.css";
      };
    };

  perSystem =
    { pkgs, ... }:
    {
      packages.ida-pro = pkgs.callPackage ./package.nix {
        libxcbImage = pkgs.libxcb-image;
        libxcbKeysyms = pkgs.libxcb-keysyms;
        libxcbRenderUtil = pkgs.libxcb-render-util;
        libxcbWm = pkgs.libxcb-wm;
      };
    };
}
