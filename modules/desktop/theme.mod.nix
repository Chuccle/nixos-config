{
  flake.nixosModules.desktop-theme =
    {
      lib,
      pkgs,
      ...
    }:
    let
      inherit (lib.lists) singleton;
    in
    {
      config = {
        fonts.packages = [
          pkgs.dejavu_fonts
          pkgs.noto-fonts-color-emoji
        ];

        fonts.fontconfig.defaultFonts = {
          sansSerif = singleton "DejaVu Sans";
          monospace = singleton "DejaVu Sans Mono";
        };

        qt = {
          enable = true;
          platformTheme = "qt5ct";
          style = "breeze";
        };
      };
    };

  flake.homeModules.desktop-theme =
    { pkgs, ... }:
    {
      config = {
        packages = [
          pkgs.adw-gtk3
          pkgs.adwaita-icon-theme
        ];

        xdg.config.files."qt5ct/qt5ct.conf" = {
          generator = (pkgs.formats.ini { }).generate "qt5ct.conf";
          value.Appearance = {
            color_scheme_path = "${pkgs.libsForQt5.qt5ct}/share/qt5ct/colors/darker.conf";
            custom_palette = true;
            icon_theme = "Adwaita";
            standard_dialogs = "default";
          };
        };

        xdg.config.files."qt6ct/qt6ct.conf" = {
          generator = (pkgs.formats.ini { }).generate "qt6ct.conf";
          value.Appearance = {
            color_scheme_path = "${pkgs.qt6Packages.qt6ct}/share/qt6ct/colors/darker.conf";
            custom_palette = true;
            icon_theme = "Adwaita";
            standard_dialogs = "default";
          };
        };

        rum.misc.gtk = {
          enable = true;
          settings = {
            theme-name = "adw-gtk3-dark";
            icon-theme-name = "Adwaita";
            font-name = "DejaVu Sans 10";
            application-prefer-dark-theme = true;
          };
        };
      };
    };
}
