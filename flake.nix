{
  description = "composable nixos — DE x theme";

  nixConfig = {
    # `zeroclaw` and the rest of the llm-agents package set are prebuilt on
    # numtide's cache — without it every rebuild of the agent host compiles a
    # large Rust workspace from source. nix-community carries the rest.
    extra-substituters = [
      "https://cache.numtide.com"
      "https://nix-community.cachix.org"
    ];

    extra-trusted-public-keys = [
      "niks3.numtide.com-1:DTx8wZduET09hRmMtKdQDxNNthLQETkc/yaX7M4qK0g="
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

  inputs.llm-agents = {
    url = "github:numtide/llm-agents.nix";
    inputs.nixpkgs.follows = "nixpkgs";
  };

  # Source-only, purely for `nix/module.nix` — the ZeroClaw binary itself comes
  # from llm-agents. Pinned to the same tag llm-agents packages (v0.8.4) so the
  # module and the binary never drift apart; upstream's own flake exports no
  # zeroclaw package, so there is nothing else to take from it.
  inputs.zeroclaw = {
    url = "github:zeroclaw-labs/zeroclaw/v0.8.4";
    flake = false;
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
