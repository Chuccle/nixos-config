{
  perSystem =
    { pkgs, ... }:
    {
      # Hyphenated attrs can't be callPackage parameter names, so they are passed
      # explicitly; everything else is auto-filled from pkgs.
      packages.ida-pro = pkgs.callPackage ./package.nix {
        libxcbImage = pkgs.libxcb-image;
        libxcbKeysyms = pkgs.libxcb-keysyms;
        libxcbRenderUtil = pkgs.libxcb-render-util;
        libxcbWm = pkgs.libxcb-wm;
      };
    };
}
