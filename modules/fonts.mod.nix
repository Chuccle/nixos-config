{
  flake.nixosModules.fonts =
    { lib, pkgs, ... }:
    let
      inherit (lib.lists) singleton;
    in
    {
      console = {
        earlySetup = true;
        font = "Lat2-Terminus16";
        packages = singleton pkgs.terminus_font;
      };

      fonts.packages = [
        pkgs.lexend
        pkgs.nerd-fonts.jetbrains-mono

        pkgs.noto-fonts
        pkgs.noto-fonts-cjk-sans
        pkgs.noto-fonts-lgc-plus
        pkgs.noto-fonts-color-emoji
      ];

      fonts.fontconfig.defaultFonts = {
        sansSerif = singleton "Lexend";
        monospace = singleton "JetBrainsMono Nerd Font";
      };
    };
}
