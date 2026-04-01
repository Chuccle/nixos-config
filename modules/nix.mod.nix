{
  flake.nixosModules.nix =
    { inputs, ... }:
    {
      nix = {
        gc = {
          automatic = true;
          dates = "weekly";
          options = "--delete-older-than 14d";
        };

        settings.auto-optimise-store = true;

        registry.nixpkgs.flake = inputs.nixpkgs;
        nixPath = [ "nixpkgs=${inputs.nixpkgs}" ];
      };
    };
}
