{
  description = "NixOS hosts and modules";

  nixConfig = {
    extra-substituters = [
      "https://cache.numtide.com"
      "https://chuccle.cachix.org"
      "https://niri.cachix.org"
      "https://nix-community.cachix.org"
    ];

    extra-trusted-public-keys = [
      "niks3.numtide.com-1:DTx8wZduET09hRmMtKdQDxNNthLQETkc/yaX7M4qK0g="
      "chuccle.cachix.org-1:FT8Le4No+sZMyaQEqyWAJdbikbo9CGRQxnFkB9Tl27w="
      "niri.cachix.org-1:Wv0OmO7PsuocRKzfDoJ3mulSl7Z6oezYhGhR+3W2964="
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

  inputs.llmAgents = {
    url = "github:numtide/llm-agents.nix/87add0847ae4744de25a41a9c77a9ef257bea01b";
  };

  inputs.treefmt-nix = {
    url = "github:numtide/treefmt-nix";
    inputs.nixpkgs.follows = "nixpkgs";
  };

  inputs.dms = {
    url = "github:AvengeMedia/DankMaterialShell";
    inputs.nixpkgs.follows = "nixpkgs";
  };

  inputs.niri = {
    url = "github:sodiboo/niri-flake";
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

  inputs.lanzaboote = {
    url = "github:nix-community/lanzaboote";
    inputs.nixpkgs.follows = "nixpkgs";
  };

  inputs.ublock = {
    url = "github:gorhill/uBlock";
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

        imports = ./. |> listFilesRecursive |> filter (hasSuffix ".mod.nix");

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
