{
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
