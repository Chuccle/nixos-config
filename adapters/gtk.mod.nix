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
      # hjem-rum's own `rum.misc.gtk` module owns writing both gtk-3.0 and
      # gtk-4.0 settings.ini from one attrset (it auto-prepends "gtk-" to
      # each key) rather than us hand-rolling `lib.generators.toINI` and
      # duplicating the file across both versions.
      rum.misc.gtk.enable = true;
      rum.misc.gtk.settings = {
        theme-name = theme.gtk.name;
        icon-theme-name = theme.icons.name;
        cursor-theme-name = theme.cursor.name;
        cursor-theme-size = theme.cursor.size;
        font-name = "${theme.font.sans.name} ${toString theme.font.size.normal}";
        application-prefer-dark-theme = 1;
      };
    };
}
