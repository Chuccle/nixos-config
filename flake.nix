{
  description = "composable nixos — DE x theme";

  nixConfig = {
    # SUBSTITUTERS
    # Nix reads `nixConfig` from the top-level flake only, so a cache an input
    # declares for itself is never consulted — every cache this repo wants has
    # to be named here, and the two lists below are positional: nth key signs
    # nth substituter.
    #
    #   lantian        the CachyOS kernels. `nix-cachyos-kernel` declares this
    #                  cache in its own `nixConfig`, where nothing reads it,
    #                  and its `overlays.pinned` — which `cachy` uses — exists
    #                  precisely so the built kernel matches the cached one.
    #                  Without the substituter that pinning buys nothing and
    #                  `box` and both ISOs compile a patched kernel from
    #                  source.
    #   chuccle        this repo's own CI output. The cache workflow has been
    #                  pushing every host toplevel and server tarball here all
    #                  along and only the workflow read them back, so a local
    #                  `nixos-rebuild` rebuilt what CI had already built.
    #   nix-community  carries the rest.
    #
    # This list is duplicated as `nix.settings.extra-substituters` — in
    # `modules/nix.mod.nix` for the general caches and in `modules/cachy.mod.nix`
    # for lantian, beside the overlay that needs it. That is not tidy, but
    # `nixConfig` is advisory: it is offered to whoever evaluates the flake and
    # silently dropped unless they have accepted it, which a headless
    # `nixos-rebuild` never has. `nix.settings` is what the machines actually
    # read.
    extra-substituters = [
      "https://attic.xuyh0120.win/lantian"
      "https://chuccle.cachix.org"
      "https://nix-community.cachix.org"
    ];

    extra-trusted-public-keys = [
      "lantian:EeAUQ+W+6r7EtwnmYjeVwx5kOGEBpjlBfPlzGlTNvHc="
      "chuccle.cachix.org-1:FT8Le4No+sZMyaQEqyWAJdbikbo9CGRQxnFkB9Tl27w="
      "nix-community.cachix.org-1:mB9FSh9qf2dCimDSUo8Zy7bkq5CX+/rkCWyvRCYg3Fs="
    ];

    experimental-features = [
      "flakes"
      "nix-command"
      "pipe-operators"
    ];
  };

  inputs.nixpkgs = {
    url = "github:NixOS/nixpkgs/nixos-unstable-small";
  };

  inputs.flake-parts = {
    url = "github:hercules-ci/flake-parts";
    inputs.nixpkgs-lib.follows = "nixpkgs";
  };

  inputs.nix-cachyos-kernel = {
    url = "github:xddxdd/nix-cachyos-kernel/release";
  };

  inputs.treefmt-nix = {
    url = "github:numtide/treefmt-nix";
    inputs.nixpkgs.follows = "nixpkgs";
  };

  inputs.hjem = {
    url = "github:feel-co/hjem";
    inputs.nixpkgs.follows = "nixpkgs";
  };

  inputs.hjem-rum = {
    url = "github:snugnug/hjem-rum";
    inputs.nixpkgs.follows = "nixpkgs";
    inputs.hjem.follows = "hjem";
  };

  inputs.helium = {
    url = "github:AlvaroParker/helium-nix";
    inputs.nixpkgs.follows = "nixpkgs";
  };

  inputs.ublock = {
    url = "github:gorhill/uBlock";
    flake = false;
  };

  inputs.dms = {
    url = "github:AvengeMedia/DankMaterialShell/stable";
    inputs.nixpkgs.follows = "nixpkgs";
  };

  inputs.agenix = {
    url = "github:ryantm/agenix";
    inputs.nixpkgs.follows = "nixpkgs";
  };

  outputs =
    inputs:
    inputs.flake-parts.lib.mkFlake { inherit inputs; } (
      {
        lib,
        ...
      }:
      let
        inherit (lib.filesystem) listFilesRecursive;
        inherit (lib.lists) filter singleton;
        inherit (lib.strings) getName hasSuffix;
      in
      {
        systems = singleton "x86_64-linux";

        imports = filter (hasSuffix ".mod.nix") (listFilesRecursive ./.);

        perSystem =
          { system, ... }:
          {
            _module.args.pkgs = import inputs.nixpkgs {
              inherit system;
              config.allowUnfreePredicate = pkg: getName pkg == "ida-pro";
            };
          };
      }
    );
}
