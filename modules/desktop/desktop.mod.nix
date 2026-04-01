{
  flake.nixosModules.desktop =
    {
      lib,
      pkgs,
      config,
      ...
    }:
    let
      inherit (lib.modules) mkDefault mkIf mkMerge;
      inherit (lib.options) mkOption;
      inherit (lib.types) enum nullOr;

      cfg = config.desktop;

      pantheonDE = mkIf (cfg.environment == "pantheon") {
        services.xserver.enable = true;
        services.xserver.desktopManager.pantheon.enable = true;

        desktop.greeter = mkDefault "lightdm-pantheon";

        environment.systemPackages = with pkgs; [
          pantheon.elementary-files
          pantheon.elementary-settings-daemon
          pantheon.elementary-terminal
          pantheon.sideload
        ];

        services.gvfs.enable = true;
        services.tumbler.enable = true;

        xdg.portal.enable = true;
        xdg.portal.extraPortals = [ pkgs.xdg-desktop-portal-gtk ];
      };

      niriDE = mkIf (cfg.environment == "niri") {
        programs.niri.enable = true;

        desktop.greeter = mkDefault "greetd-tuigreet";
        desktop.greeterSession = mkDefault "niri-session";

        security.rtkit.enable = true;
        services.pipewire.enable = true;
        services.pipewire.alsa.enable = true;
        services.pipewire.alsa.support32Bit = true;
        services.pipewire.pulse.enable = true;

        xdg.portal.enable = true;
        xdg.portal.extraPortals = [ pkgs.xdg-desktop-portal-gnome ];

        environment.systemPackages = with pkgs; [
          fuzzel
          mako
          waybar
          swaylock
          swayidle
          wl-clipboard
          grim
          slurp
        ];
      };

      plasmaDE = mkIf (cfg.environment == "plasma") {
        services.desktopManager.plasma6.enable = true;

        desktop.greeter = mkDefault "sddm-wayland";
        desktop.defaultSession = mkDefault "plasma";

        security.rtkit.enable = true;
        services.pipewire.enable = true;
        services.pipewire.alsa.enable = true;
        services.pipewire.alsa.support32Bit = true;
        services.pipewire.pulse.enable = true;

        xdg.portal.enable = true;

        environment.systemPackages = with pkgs; [
          kdePackages.discover
          kdePackages.kate
          kdePackages.kcalc
          kdePackages.ark
        ];
      };
    in
    {
      options.desktop = {
        environment = mkOption {
          type = nullOr (enum [
            "pantheon"
            "niri"
            "plasma"
          ]);
          default = null;
          description = ''
            Desktop environment to enable.

              "pantheon" — elementaryOS / Pantheon shell (X11)
              "niri"     — Niri scrollable-tiling Wayland compositor
              "plasma"   — KDE Plasma 6 (Wayland)

            null → headless / server, no desktop started.
          '';
          example = "plasma";
        };

        theme = mkOption {
          type = nullOr (enum [
            "windows95"
            "liquid-glass"
            "big-sur"
          ]);
          default = null;
          description = ''
            Visual theme applied system-wide.

              "windows95"    — Chicago95 (retro Windows 95 aesthetic)
              "liquid-glass" — Frosted glass dark (macOS Tahoe aesthetic)
              "big-sur"      — WhiteSur dark (macOS Big Sur aesthetic)

            Theme config lives in modules/desktop/themes/<name>.mod.nix.
            null → DE defaults, no theme applied.
          '';
          example = "liquid-glass";
        };
      };

      config = mkIf (cfg.environment != null) (mkMerge [
        pantheonDE
        niriDE
        plasmaDE
      ]);
    };
}
