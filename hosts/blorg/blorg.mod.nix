{ inputs, self, ... }:
{
  flake.nixosConfigurations.blorg = inputs.nixpkgs.lib.nixosSystem {
    modules = [
      ./hardware-configuration.nix
      self.nixosModules.boot-desktop
      self.nixosModules.kernel-hardening
      self.nixosModules.no-wall
      self.nixosModules.secure-boot
      self.nixosModules.amd-cpu
      self.nixosModules.nvidia
      self.nixosModules.nix
      self.nixosModules.nh
      self.nixosModules.nuke-default-packages
      self.nixosModules.security
      self.nixosModules.ssh
      self.nixosModules.steam
      self.nixosModules.syncthing
      self.nixosModules.shell
      self.nixosModules.home
      self.nixosModules.helium
      self.nixosModules.desktop-session
      self.nixosModules.desktop-audio
      self.nixosModules.desktop-theme

      (
        { config, lib, ... }:
        let
          inherit (lib.lists) singleton;
        in
        {
          networking.hostName = "blorg";

          networking.networkmanager.enable = true;
          hardware.bluetooth.enable = true;
          hardware.enableRedistributableFirmware = true;

          security.pki.certificateFiles = singleton ./root.crt;

          console.keyMap = "uk";

          programs.niri.settings.input.keyboard.xkb.layout = "gb";

          programs.niri.settings.outputs = {
            "DP-1" = {
              mode = {
                width = 2560;
                height = 1440;
                refresh = 143.999;
              };
              position = {
                x = 1080;
                y = 0;
              };
              scale = 1;
              focus-at-startup = true;
              variable-refresh-rate = true;
            };

            "HDMI-A-1" = {
              mode = {
                width = 1920;
                height = 1080;
                refresh = 60.0;
              };
              position = {
                x = 0;
                y = 0;
              };
              scale = 1;
              transform.rotation = 90;
            };
          };

          services.fstrim.enable = true;

          services.displayManager.sddm = {
            enable = true;
            wayland.enable = true;
          };

          time.timeZone = "Europe/London";
          i18n.defaultLocale = "en_GB.UTF-8";

          shell.default = "nushell";

          users.users.desktop = {
            isNormalUser = true;
            extraGroups = [
              "networkmanager"
              "wheel"
            ];
          };

          services.syncthing = {
            user = "desktop";
            dataDir = config.users.users.${config.services.syncthing.user}.home;
          };

          home.users.desktop = {
            imports = [
              self.homeModules.home
              self.homeModules.desktop-niri
              self.homeModules.desktop-dms
              self.homeModules.desktop-theme
              self.homeModules.file-explorer
              self.homeModules.helium
              self.homeModules.ida-pro
              self.homeModules.desktop-ghostty
              self.homeModules.desktop-tools
              self.homeModules.bitwarden
              self.homeModules.btop
              self.homeModules.haruna
              self.homeModules.jujutsu
              self.homeModules.obs-studio
              self.homeModules.qbittorrent
              self.homeModules.vscodium
            ];
          };

          nixpkgs.hostPlatform = "x86_64-linux";
          system.stateVersion = "26.05";
        }
      )
    ];
  };
}
