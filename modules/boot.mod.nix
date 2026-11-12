{
  flake.nixosModules.boot = {
    boot.loader.systemd-boot = {
      enable = true;
      editor = false;
    };

    boot.loader.efi.canTouchEfiVariables = true;
    boot.tmp.cleanOnBoot = true;
  };
}
