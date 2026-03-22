{
  description = "composable nixos — DE × theme";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    treefmt-nix.url = "github:numtide/treefmt-nix";
    nix-cachyos-kernel.url = "github:xddxdd/nix-cachyos-kernel/release";

    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    plasma-manager = {
      url = "github:nix-community/plasma-manager";
      inputs.nixpkgs.follows = "nixpkgs";
      inputs.home-manager.follows = "home-manager";
    };
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
      inherit (nixpkgs) lib;

      treefmtEval = treefmt-nix.lib.evalModule pkgs ./treefmt.nix;

      validateKdl =
        name: path:
        pkgs.runCommand "niri-validate-${name}" {
          nativeBuildInputs = [ pkgs.niri ];
        } "niri validate -c ${path} && touch $out";

      mkSystem =
        { de, theme }:
        lib.nixosSystem {
          inherit system;
          specialArgs = { inherit inputs; };
          modules = [
            ./modules/theme-options.nix
            theme
            de
            ./modules/base.nix
            ./hardware/box.nix
            home-manager.nixosModules.home-manager
            {
              home-manager = {
                useGlobalPkgs = true;
                useUserPackages = true;
                users.charlie = ./modules/home.nix;
              };
            }
          ];
        };

      des = {
        niri = ./profiles/de/niri.nix;
        plasma = ./profiles/de/plasma.nix;
        elementary = ./profiles/de/elementary.nix;
      };

      themes = {
        win95 = ./profiles/theme/win95.nix;
        glass = ./profiles/theme/liquid-glass.nix;
        whitesur = ./profiles/theme/whitesur.nix;
      };

      kdlFiles = {
        liquid-glass = ./niri/liquid-glass.kdl;
        win95 = ./niri/win95.kdl;
        whitesur = ./niri/whitesur.kdl;
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

      checks.${system} = {
        formatting = treefmtEval.config.build.check self;
      }
      // lib.mapAttrs' (
        name: path: lib.nameValuePair "niri-validate-${name}" (validateKdl name path)
      ) kdlFiles;

      nixosConfigurations = lib.listToAttrs (
        map
          (
            { de, theme }:
            lib.nameValuePair "box-${de}-${theme}" (mkSystem {
              de = des.${de};
              theme = themes.${theme};
            })
          )
          (
            lib.cartesianProduct {
              de = lib.attrNames des;
              theme = lib.attrNames themes;
            }
          )
      );
    };
}
