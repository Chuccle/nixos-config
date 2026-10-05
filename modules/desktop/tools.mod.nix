{
  flake.homeModules.desktop-tools =
    { pkgs, ... }:
    {
      config = {
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

        programs.bottom.enable = true;
        programs.helix.enable = true;
        programs.nushell.enable = true;

        programs.starship = {
          enable = true;
          integrations.nushell.enable = true;
        };

        programs.zoxide = {
          enable = true;
          integrations.nushell.enable = true;
        };
      };
    };
}
