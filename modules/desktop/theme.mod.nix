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

  flake.homeModules.desktop-theme =
    { pkgs, ... }:
    let
      qtct = name: package: {
        generator = (pkgs.formats.ini { }).generate "${name}.conf";
        value.Appearance = {
          color_scheme_path = "${package}/share/${name}/colors/darker.conf";
          custom_palette = true;
          icon_theme = "Adwaita";
          standard_dialogs = "default";
        };
      };
    in
    {
      packages = [
        pkgs.adw-gtk3
        pkgs.adwaita-icon-theme
        pkgs.kdePackages.breeze
      ];

      xdg.config.files = {
        "qt5ct/qt5ct.conf" = qtct "qt5ct" pkgs.libsForQt5.qt5ct;
        "qt6ct/qt6ct.conf" = qtct "qt6ct" pkgs.qt6Packages.qt6ct;
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
}
