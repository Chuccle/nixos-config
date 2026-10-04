{
  flake.nixosModules.amd-cpu = {
    hardware.cpu.amd.updateMicrocode = true;
  };
}
