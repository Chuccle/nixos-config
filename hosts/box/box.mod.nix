{ inputs, self, ... }:
{
  flake.nixosConfigurations.box = inputs.nixpkgs.lib.nixosSystem {
    modules = [
      self.nixosModules.bitwarden
      self.nixosModules.boot
      self.nixosModules.cachy
      self.nixosModules.documentation
      self.nixosModules.fonts
      self.nixosModules.helium
      self.nixosModules.home
      self.nixosModules.networkmanager
      self.nixosModules.nh
      self.nixosModules.nix
      self.nixosModules.nuke-default-packages
      self.nixosModules.packages-debugging
      self.nixosModules.security
      self.nixosModules.shell
      self.nixosModules.steam
      self.nixosModules.unfree

      {
        home.extraModules = [
          self.homeModules.bitwarden
          self.homeModules.btop
          self.homeModules.difftastic
          self.homeModules.file-explorer
          self.homeModules.foot
          self.homeModules.gh
          self.homeModules.git
          self.homeModules.haruna
          self.homeModules.helium
          self.homeModules.helix
          self.homeModules.helix-desktop
          self.homeModules.home
          self.homeModules.jujutsu
          self.homeModules.nushell
          self.homeModules.packages-debugging
          self.homeModules.packages-dev-tools-cc
          self.homeModules.packages-dev-tools-go
          self.homeModules.packages-dev-tools-python
          self.homeModules.packages-dev-tools-rust
          self.homeModules.packages-media
          self.homeModules.packages-shell-utils
          self.homeModules.packages-wisdom
          self.homeModules.use-xdg-dirs
          self.homeModules.zoxide
        ];

        networking.hostName = "box";

        users.users.box = {
          name = "box";
          isNormalUser = true;
        };
        home.users.box = { };

        shell.default = "nushell";

        hardware.enableRedistributableFirmware = true;

        fileSystems."/" = {
          device = "/dev/disk/by-label/nixos";
          fsType = "ext4";
        };

        fileSystems."/boot" = {
          device = "/dev/disk/by-label/boot";
          fsType = "vfat";
        };

        nixpkgs.hostPlatform = "x86_64-linux";
        system.stateVersion = "25.11";
      }
    ];
  };
}
