{
  flake.nixosModules.nix =
    { inputs, lib, ... }:
    let
      inherit (lib.lists) singleton;
    in
    {
      nix = {
        gc = {
          automatic = true;
          dates = "weekly";
          options = "--delete-older-than 14d";
        };

        settings.auto-optimise-store = true;

        registry.nixpkgs.flake = inputs.nixpkgs;
        nixPath = singleton "nixpkgs=${inputs.nixpkgs}";
      };
    };
}
