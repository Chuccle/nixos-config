{
  desktopHomeModules.gtk =
    { osConfig, ... }:
    let
      inherit (osConfig) theme;
    in
    {
      packages = [
        theme.gtk.package
        theme.icons.package
        theme.cursor.package
      ];

      # GTK SETTINGS
      rum.misc.gtk.enable = true;
      rum.misc.gtk.settings = {
        theme-name = theme.gtk.name;
        icon-theme-name = theme.icons.name;
        cursor-theme-name = theme.cursor.name;
        cursor-theme-size = theme.cursor.size;
        font-name = "${theme.font.sans.name} ${toString theme.font.size.normal}";

        application-prefer-dark-theme = if theme.appearance == "dark" then 1 else 0;
      };
    };
}
