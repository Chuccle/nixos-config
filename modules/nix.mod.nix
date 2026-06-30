{ inputs, ... }:
{
  flake.nixosModules.nix =
    { lib, ... }:
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
        settings.experimental-features = [
          "nix-command"
          "flakes"
          "pipe-operators"
        ];
        registry.nixpkgs.flake = inputs.nixpkgs;
        nixPath = singleton "nixpkgs=${inputs.nixpkgs}";
      };
    };
}
