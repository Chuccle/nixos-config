{ lib, ... }:

{
  imports = [ ];

  boot = {
    initrd.availableKernelModules = [
      "ata_piix"
      "mptspi"
      "uhci_hcd"
      "ehci_pci"
      "ahci"
      "sd_mod"
      "sr_mod"
    ];
    initrd.kernelModules = [ ];
    kernelModules = [ ];
    extraModulePackages = [ ];
  };

  fileSystems."/" = {
    device = "/dev/disk/by-label/nixos";
    fsType = "ext4";
  };

  fileSystems."/boot" = {
    device = "/dev/disk/by-label/boot";
    fsType = "vfat";
  };

  swapDevices = [ ];

  nixpkgs.hostPlatform = lib.mkDefault "x86_64-linux";
}
