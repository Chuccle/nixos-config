{
  description = "minimal niri nixos";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    nix-cachyos-kernel.url = "github:xddxdd/nix-cachyos-kernel/release";
  };

  outputs = { nixpkgs, home-manager, nix-cachyos-kernel, ... }@inputs:
  let
    mkSystem = theme: nixpkgs.lib.nixosSystem {
      system = "x86_64-linux";
      specialArgs = { inherit inputs theme; };
      modules = [
        home-manager.nixosModules.home-manager
        ./configuration.nix
        {
          home-manager.extraSpecialArgs = { inherit theme; };
        }
      ];
    };
  in {
    nixosConfigurations = {
      box-win95 = mkSystem (import ./themes/win95.nix);
      box-glass = mkSystem (import ./themes/liquid-glass.nix);
    };
  };
}