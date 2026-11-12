{
  flake.homeModules.haruna =
    { lib, pkgs, ... }:
    let
      inherit (lib.attrsets) genAttrs;
      inherit (lib.trivial) const flip;
    in
    {
      packages = [
        pkgs.haruna
        pkgs.kdePackages.breeze
      ];

      xdg.config.files."haruna/haruna.conf" = {
        generator = (pkgs.formats.ini { }).generate "haruna.conf";
        value.General.ColorScheme = "Breeze Dark";
      };

      xdg.mime-apps.default-applications = flip genAttrs (const "org.kde.haruna.desktop") [
        "audio/aac"
        "audio/ac3"
        "audio/flac"
        "audio/mp4"
        "audio/mpeg"
        "audio/ogg"
        "audio/vnd.wave"
        "audio/webm"
        "audio/x-matroska"
        "audio/x-mpegurl"
        "video/mp2t"
        "video/mp4"
        "video/mpeg"
        "video/ogg"
        "video/quicktime"
        "video/vnd.avi"
        "video/webm"
        "video/x-matroska"
        "video/x-ms-wmv"
      ];
    };
}
