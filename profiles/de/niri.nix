{
  config,
  pkgs,
  lib,
  ...
}:

let
  t = config.theme;
  toHex = s: lib.removePrefix "#" s;

  swaybgArgs =
    if t.wallpaper.path != null then
      [
        "${pkgs.swaybg}/bin/swaybg"
        "-m"
        "fill"
        "-i"
        "${t.wallpaper.path}"
      ]
    else if t.wallpaper.color != null then
      [
        "${pkgs.swaybg}/bin/swaybg"
        "-m"
        "solid_color"
        "-c"
        t.wallpaper.color
      ]
    else
      null;

in
{
  imports = [ ../../modules/greetd.nix ];

  options.de.niri.xwayland.enable = lib.mkOption {
    type = lib.types.bool;
    default = true;
  };

  config = {
    programs.niri.enable = true;

    greetd = {
      enable = true;
      session.command = "${pkgs.niri}/bin/niri-session";
      tuigreet.greeting = "Welcome";
    };

    hardware.graphics.enable = true;

    xdg.portal = {
      enable = true;
      extraPortals = [ pkgs.xdg-desktop-portal-gtk ];
      config.common.default = "gtk";
    };

    programs.dconf.enable = true;

    environment.systemPackages =
      with pkgs;
      [
        niri
        waybar
        swaybg
        foot
        fuzzel
        wl-clipboard
        brightnessctl
      ]
      ++ lib.optional config.de.niri.xwayland.enable pkgs.xwayland-satellite;

    theme.launcher.command = "fuzzel";

    home-manager.sharedModules = [
      (lib.mkIf (t.compositor.niri != null) {
        xdg.configFile."niri/config.kdl".source = t.compositor.niri;
      })
      {
        programs.fuzzel = {
          enable = true;
          settings = {
            main = {
              font = "${t.fonts.sans.name}:size=${toString t.fonts.sans.size}";
              icon-theme = t.gtk.icons;
            };
            colors = {
              background = "${toHex t.colors.background}ee";
              text = "${toHex t.colors.foreground}ff";
              match = "${toHex t.colors.accent}ff";
              selection = "${toHex t.colors.accent}33";
              selection-text = "${toHex t.colors.foreground}ff";
              border = "${toHex t.colors.accent}88";
            };
            border = { inherit (t.launcher.border) width radius; };
          };
        };
      }
    ];

    systemd.user.services.swaybg = lib.mkIf (swaybgArgs != null) {
      description = "swaybg wallpaper";
      wantedBy = [ "niri.service" ];
      after = [ "niri.service" ];
      serviceConfig = {
        ExecStart = lib.escapeShellArgs swaybgArgs;
        Restart = "on-failure";
        RestartSec = "2s";
      };
    };
  };
}
