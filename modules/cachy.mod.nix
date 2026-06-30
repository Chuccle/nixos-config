{ inputs, ... }:
{
  flake.nixosModules.cachy =
    { lib, pkgs, ... }:
    let
      inherit (lib.lists) singleton;
    in
    {
      boot.kernelPackages = pkgs.cachyosKernels.linuxPackages-cachyos-latest;
      nixpkgs.overlays = singleton inputs.nix-cachyos-kernel.overlays.pinned;
    };
}
