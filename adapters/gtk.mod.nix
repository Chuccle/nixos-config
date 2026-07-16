{
  desktopHomeModules.gtk =
    { lib, osConfig, ... }:
    let
      inherit (lib.generators) toINI;

      inherit (osConfig) theme;

      # GTK SETTINGS
      # Same value for GTK3 and GTK4. Theme/icon/cursor names and font from tokens.
      settings = {
        Settings = {
          gtk-theme-name = theme.gtk.name;
          gtk-icon-theme-name = theme.icons.name;
          gtk-cursor-theme-name = theme.cursor.name;
          gtk-cursor-theme-size = theme.cursor.size;
          gtk-font-name = "${theme.font.sans.name} ${toString theme.font.size.normal}";
          gtk-application-prefer-dark-theme = 1;
        };
      };

      settingsFile = {
        generator = toINI { };
        value = settings;
      };
    in
    {
      packages = [
        theme.gtk.package
        theme.icons.package
        theme.cursor.package
      ];

      xdg.config.files."gtk-3.0/settings.ini" = settingsFile;
      xdg.config.files."gtk-4.0/settings.ini" = settingsFile;
    };
}
