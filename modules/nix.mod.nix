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

        settings = (import ../flake.nix).nixConfig // {
          auto-optimise-store = true;
          nix-path = singleton "nixpkgs=${inputs.nixpkgs}";
        };

        registry.nixpkgs.flake = inputs.nixpkgs;
      };
    };
}
