{ pkgs, inputs, ... }:
{
  boot = {
    loader.systemd-boot.enable = true;
    loader.efi.canTouchEfiVariables = true;
    tmp.cleanOnBoot = true;
  };

  nixpkgs.overlays = [ inputs.nix-cachyos-kernel.overlays.pinned ];
  boot.kernelPackages = pkgs.cachyosKernels.linuxPackages-cachyos-latest;

  networking.hostName = "box";
  networking.networkmanager.enable = true;

  time.timeZone = "Europe/London";
  i18n.defaultLocale = "en_GB.UTF-8";
  console.keyMap = "uk";

  security = {
    doas.enable = true;
    sudo.enable = false;
    doas.extraRules = [
      {
        users = [ "charlie" ];
        keepEnv = true;
        persist = true;
      }
    ];
  };

  users.users.charlie = {
    isNormalUser = true;
    extraGroups = [
      "wheel"
      "networkmanager"
      "video"
      "input"
    ];
    shell = pkgs.nushell;
  };
  environment.shells = [ pkgs.nushell ];

  environment.systemPackages = with pkgs; [
    git
    uutils-coreutils-noprefix
    ripgrep
    fd
    bat
    eza
    nushell
    zoxide
    helix
  ];

  security.rtkit.enable = true;
  services.pipewire = {
    enable = true;
    alsa.enable = true;
    alsa.support32Bit = true;
    pulse.enable = true;
    jack.enable = true;
  };

  nix = {
    gc = {
      automatic = true;
      dates = "weekly";
      options = "--delete-older-than 14d";
    };

    settings = {
      auto-optimise-store = true;
      experimental-features = [
        "nix-command"
        "flakes"
      ];
      substituters = [
        "https://cache.nixos.org"
        "https://attic.xuyh0120.win/lantian"
      ];
    };

    registry.nixpkgs.flake = inputs.nixpkgs;
    nixPath = [ "nixpkgs=${inputs.nixpkgs}" ];
  };

  system.stateVersion = "25.11";
}
