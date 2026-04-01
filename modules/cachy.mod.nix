{
  flake.nixosModules.cachy =
    {
      inputs,
      pkgs,
      ...
    }:
    {
      boot.kernelPackages = pkgs.cachyosKernels.linuxPackages-cachyos-latest;
      nixpkgs.overlays = [ inputs.nix-cachyos-kernel.overlays.pinned ];
    };
}
