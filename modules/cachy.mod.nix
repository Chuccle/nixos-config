{ inputs, ... }:
{
  flake.nixosModules.cachy =
    { lib, pkgs, ... }:
    let
      inherit (lib.lists) singleton;
    in
    {
      boot.kernelPackages = pkgs.cachyosKernels.linuxPackages-cachyos-latest;

      # `pinned` rather than `default`: it builds the kernel against the exact
      # nixpkgs revision upstream's Hydra used, which is the only way the
      # cached kernel and the one this configuration asks for are the same
      # store path. The price is a second nixpkgs instance and no
      # `nixpkgs.config` applying to the kernel.
      nixpkgs.overlays = singleton inputs.nix-cachyos-kernel.overlays.pinned;

      # And the cache that pinning is for. Upstream names it in its own
      # flake's `nixConfig`, which nothing consults — Nix reads `nixConfig`
      # from the top-level flake only — so without repeating it here the
      # pinning above buys nothing and every kernel bump compiles a fully
      # patched CachyOS kernel locally. Declared beside the overlay because
      # the two are one decision; the flake's `nixConfig` carries the same
      # pair for whoever builds these hosts from outside them.
      #
      # Note that this only takes effect from the *next* rebuild: the
      # substituter reaches `/etc/nix/nix.conf` in the same generation that
      # first needs the kernel, too late to fetch it.
      nix.settings.extra-substituters = singleton "https://attic.xuyh0120.win/lantian";
      nix.settings.extra-trusted-public-keys = singleton "lantian:EeAUQ+W+6r7EtwnmYjeVwx5kOGEBpjlBfPlzGlTNvHc=";
    };
}
