{ lib, modulesPath, ... }:
let
  inherit (lib.lists) singleton;
  inherit (lib.modules) mkDefault;
in
{
  imports = singleton <| modulesPath + "/installer/scan/not-detected.nix";

  boot.initrd.availableKernelModules = [
    "nvme"
    "ahci"
    "xhci_pci"
    "usbhid"
    "usb_storage"
    "sd_mod"
  ];

  boot.kernelModules = singleton "kvm-amd";

  # FILESYSTEM LABELS REMAIN PLACEHOLDERS UNTIL PARTITIONING
  fileSystems."/" = {
    device = "/dev/disk/by-label/nixos";
    fsType = "ext4";
  };

  fileSystems."/boot" = {
    device = "/dev/disk/by-label/EFI";
    fsType = "vfat";
  };

  nixpkgs.hostPlatform = mkDefault "x86_64-linux";
}
