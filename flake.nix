{
  description = "composable nixos — DE × theme";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

    treefmt-nix.url = "github:numtide/treefmt-nix";

    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    plasma-manager = {
      url = "github:nix-community/plasma-manager";
      inputs.nixpkgs.follows = "nixpkgs";
      inputs.home-manager.follows = "home-manager";
    };

    nix-cachyos-kernel.url = "github:xddxdd/nix-cachyos-kernel/release";
  };

  outputs =
    {
      self,
      nixpkgs,
      home-manager,
      treefmt-nix,
      ...
    }@inputs:
    let
      system = "x86_64-linux";
      pkgs = nixpkgs.legacyPackages.${system};

      treefmtEval = treefmt-nix.lib.evalModule pkgs ./treefmt.nix;

      mkSystem =
        {
          de,
          theme,
          hardware,
          extra ? [ ],
        }:
        nixpkgs.lib.nixosSystem {
          inherit system;
          specialArgs = { inherit inputs; };
          modules = [
            ./modules/theme-options.nix
            theme
            de
            ./modules/base.nix
            hardware
            home-manager.nixosModules.home-manager
            {
              home-manager = {
                useGlobalPkgs = true;
                useUserPackages = true;
                users.charlie = ./modules/home.nix;
              };
            }
          ]
          ++ extra;
        };

    in
    {
      devShells.${system}.default = pkgs.mkShell {
        packages = with pkgs; [
          deadnix
          statix
          nil
        ];
      };

      formatter.${system} = treefmtEval.config.build.wrapper;
      checks.${system}.formatting = treefmtEval.config.build.check self;

      nixosConfigurations = {
        box-niri-win95 = mkSystem {
          de = ./profiles/de/niri.nix;
          theme = ./profiles/theme/win95.nix;
          hardware = ./hardware/box.nix;
        };
        box-niri-glass = mkSystem {
          de = ./profiles/de/niri.nix;
          theme = ./profiles/theme/liquid-glass.nix;
          hardware = ./hardware/box.nix;
        };
        box-plasma-win95 = mkSystem {
          de = ./profiles/de/plasma.nix;
          theme = ./profiles/theme/win95.nix;
          hardware = ./hardware/box.nix;
        };
        box-plasma-glass = mkSystem {
          de = ./profiles/de/plasma.nix;
          theme = ./profiles/theme/liquid-glass.nix;
          hardware = ./hardware/box.nix;
        };
        box-elementary-win95 = mkSystem {
          de = ./profiles/de/elementary.nix;
          theme = ./profiles/theme/win95.nix;
          hardware = ./hardware/box.nix;
        };
        box-elementary-glass = mkSystem {
          de = ./profiles/de/elementary.nix;
          theme = ./profiles/theme/liquid-glass.nix;
          hardware = ./hardware/box.nix;
        };
      };
    };
}
