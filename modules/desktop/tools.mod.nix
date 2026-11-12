{
  flake.homeModules.desktop-tools =
    { pkgs, ... }:
    {
      packages = [
        pkgs.bat
        pkgs.dua
        pkgs.dust
        pkgs.eza
        pkgs.fd
        pkgs.procs
        pkgs.ripgrep
        pkgs.sd
        pkgs.uutils-coreutils-noprefix
        pkgs.yazi
      ];
    };
}
