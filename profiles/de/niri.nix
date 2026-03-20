# profiles/de/niri.nix
#
# Bare Wayland compositor DE profile.
# Enables niri, greetd/tuigreet, xdg-portal, waybar, swaybg.
# All visual config is read from config.theme.* — nothing is hardcoded here.

{
  config,
  pkgs,
  lib,
  ...
}:

let
  t = config.theme;
  toHex = s: lib.removePrefix "#" s;

  # swaybg wallpaper command: prefer image, fall back to solid colour.
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
  imports = [ ../../modules/greetd.nix ]; # relative from profiles/de/

  options.de.niri.xwayland.enable = lib.mkOption {
    type = lib.types.bool;
    default = true;
  };

  config = {
    # ── niri ────────────────────────────────────────────────────────────────────
    programs.niri.enable = true;

    # ── Greeter ─────────────────────────────────────────────────────────────────
    greetd = {
      enable = true;
      session.command = "${pkgs.niri}/bin/niri-session";
      tuigreet.greeting = "Welcome";
    };

    # ── Graphics ────────────────────────────────────────────────────────────────
    hardware.graphics.enable = true;

    # ── XDG portal ──────────────────────────────────────────────────────────────
    # xdg-desktop-portal-gtk is the correct lightweight backend for non-GNOME
    # Wayland compositors. -gnome brings in unnecessary GNOME deps.
    xdg.portal = {
      enable = true;
      extraPortals = [ pkgs.xdg-desktop-portal-gtk ];
      config.common.default = "gtk";
    };

    programs.dconf.enable = true;

    # ── System packages for bare compositor session ──────────────────────────────
    environment.systemPackages =
      with pkgs;
      [
        niri
        waybar
        swaybg
        foot
        fuzzel
        wl-clipboard
        grim
        slurp
        brightnessctl
      ]
      ++ lib.optional config.de.niri.xwayland.enable pkgs.xwayland-satellite;

    theme.launcher.command = "fuzzel";

    # ── niri config — sourced from theme.compositor.niri ────────────────────────
    # Written into the system's xdg config dir so it's available before
    # home-manager runs. home-manager's xdg.configFile wins if both are set,
    # but in this setup we let home.nix handle it via the osConfig.theme path.
    # (See home.nix — xdg.configFile."niri/config.kdl".source)

    # ── home-manager hook — install niri config ──────────────────────────────────
    # profiles/de/niri.nix
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

    # ── swaybg — run via niri spawn-at-startup, but also available as a unit ────
    # The KDL files already contain spawn-at-startup directives. This systemd
    # user service is a belt-and-suspenders fallback and provides clean restart.
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
