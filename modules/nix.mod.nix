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

        # SUBSTITUTERS
        settings.extra-substituters = [
          "https://chuccle.cachix.org"
          "https://nix-community.cachix.org"
        ];

        settings.extra-trusted-public-keys = [
          "chuccle.cachix.org-1:FT8Le4No+sZMyaQEqyWAJdbikbo9CGRQxnFkB9Tl27w="
          "nix-community.cachix.org-1:mB9FSh9qf2dCimDSUo8Zy7bkq5CX+/rkCWyvRCYg3Fs="
        ];

        registry.nixpkgs.flake = inputs.nixpkgs;
        nixPath = singleton "nixpkgs=${inputs.nixpkgs}";
      };
    };
}
