{ pkgs, inputs, ... }: {

  imports = [ ./hardware-configuration.nix ];

  # ── Kernel ──────────────────────────────────────
  nixpkgs.overlays = [ inputs.nix-cachyos-kernel.overlays.pinned ];
  boot.kernelPackages = pkgs.cachyosKernels.linuxPackages-cachyos-latest;

  # binary cache for the kernel — avoids local builds
  nix.settings.substituters = [
    "https://cache.nixos.org"
    "https://attic.xuyh0120.win/lantian"
  ];
  nix.settings.trusted-public-keys = [
    "cache.nixos.org-1:6NCHdD59X431o0gWypbMrAURkbJ16ZPMQFGspcDShjY="
    "lantian:EeAUQ+W+6r7EtwnmYjeVwx5kOGEBpjlBfPlzGlTNvHc="
  ];

  # ── Boot ────────────────────────────────────────
  boot.loader.systemd-boot.enable      = true;
  boot.loader.efi.canTouchEfiVariables = true;

  boot.tmp.cleanOnBoot = true;

  # ── Network ─────────────────────────────────────
  networking.hostName          = "box";
  networking.networkmanager.enable = true;

  # ── Locale ──────────────────────────────────────
  time.timeZone      = "Europe/London";
  i18n.defaultLocale = "en_GB.UTF-8";
  
  console.keyMap = "uk";

  # ── Wayland ─────────────────────────────────────
  hardware.graphics.enable = true;

  # ── doas, no sudo ───────────────────────────────
  security.doas.enable = true;
  security.sudo.enable = false;
  security.doas.extraRules = [{
    users   = [ "charlie" ];
    keepEnv = true;
    persist = true;
  }];

  # ── User ────────────────────────────────────────
  users.users.charlie = {
    isNormalUser = true;
    extraGroups  = [ "wheel" "networkmanager" "video" "input" ];
    shell        = pkgs.nushell;
  };
  environment.shells = [ pkgs.nushell ];

  # ── System packages (keep minimal) ──────────────
  environment.systemPackages = with pkgs; [
    niri
    git
    uutils-coreutils-noprefix
  ];

  # ── home-manager ────────────────────────────────
  home-manager.useGlobalPkgs   = true;
  home-manager.useUserPackages = true;
  home-manager.users.charlie   = import ./home.nix;

  # ── Nix daemon ──────────────────────────────────
  nix.settings.experimental-features = [ "nix-command" "flakes" ];

  # ── xdg ─────────────────────────────────────────
  xdg.portal = {
    enable = true;
    extraPortals = [ pkgs.xdg-desktop-portal-gnome ];
    config.common.default = "*";
  };

  programs.dconf.enable = true;
  
  # ── PipeWire ─────────────────────────────────────────
  security.rtkit.enable = true;
  services.pipewire = {
    enable = true;
    alsa.enable = true;
    alsa.support32Bit = true;
    pulse.enable = true;
    jack.enable = true;
  };

  system.stateVersion = "25.11";
}