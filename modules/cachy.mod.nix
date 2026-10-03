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

      nix.settings.extra-substituters = singleton "https://attic.xuyh0120.win/lantian";
      nix.settings.extra-trusted-public-keys = singleton "lantian:EeAUQ+W+6r7EtwnmYjeVwx5kOGEBpjlBfPlzGlTNvHc=";
    };
}
