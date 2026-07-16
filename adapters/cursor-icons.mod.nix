{
  desktopHomeModules.cursor-icons =
    { lib, osConfig, ... }:
    let
      inherit (lib.generators) toINI;

      inherit (osConfig) theme;
    in
    {
      # CURSOR
      # XCURSOR_* covers Wayland/Qt/XWayland clients; the default index.theme
      # covers apps that read ~/.icons.
      environment.sessionVariables.XCURSOR_THEME = theme.cursor.name;
      environment.sessionVariables.XCURSOR_SIZE = toString theme.cursor.size;

      files.".icons/default/index.theme" = {
        generator = toINI { };
        value."Icon Theme" = {
          Name = "Default";
          Comment = "Default cursor theme";
          Inherits = theme.cursor.name;
        };
      };
    };
}
