{
  description = "composable nixos — DE x theme";

  nixConfig = {
    extra-substituters = [
      "https://cache.garnix.io/"
      "https://nix-community.cachix.org"
    ];

    extra-trusted-public-keys = [
      "cache.garnix.io:CTFPyKSLcx5RMJKfLo5EEPUObbA78b0YQ2DTCJXqr9g="
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
    inputs.ndg.follows = "";
    inputs.treefmt-nix.follows = "";
  };

  outputs =
    inputs:
    inputs.flake-parts.lib.mkFlake { inherit inputs; } (
      { lib, ... }:
      let
        inherit (lib.filesystem) listFilesRecursive;
        inherit (lib.lists) filter;
        inherit (lib.strings) hasSuffix;
      in
      {
        systems = [ "x86_64-linux" ];

        imports = [
          inputs.treefmt-nix.flakeModule
        ]
        ++ filter (hasSuffix ".mod.nix") (listFilesRecursive ./.);

        perSystem =
          { pkgs, ... }:
          {
            treefmt = {
              projectRootFile = "flake.nix";
              programs.nixfmt.enable = true;
              programs.prettier = {
                enable = true;
                package = pkgs.prettier;
                includes = [
                  "*.yml"
                  "*.yaml"
                ];
              };
            };
          };
      }
    );
}
