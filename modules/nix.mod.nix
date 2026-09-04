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
        # The same caches the flake's `nixConfig` offers, written into
        # `/etc/nix/nix.conf` so the machine actually uses them. `nixConfig`
        # alone does not: Nix treats it as a proposal that has to be accepted
        # once per user before it takes effect, and a `nixos-rebuild` with
        # nobody at the terminal never accepts it — so every one of these hosts
        # has been rebuilding from source what it could have fetched.
        #
        # `extra-` rather than plain `substituters`: the NixOS options carry
        # cache.nixos.org as their default, and a bare definition would replace
        # it rather than add to it.
        #
        # The lantian cache is deliberately not here. It is only wanted by
        # hosts running the CachyOS kernel, and it is declared beside the
        # overlay that needs it in `modules/cachy.mod.nix` — which the ISOs
        # import without importing this module.
        settings.extra-substituters = [
          "https://cache.numtide.com"
          "https://chuccle.cachix.org"
          "https://nix-community.cachix.org"
        ];

        settings.extra-trusted-public-keys = [
          "niks3.numtide.com-1:DTx8wZduET09hRmMtKdQDxNNthLQETkc/yaX7M4qK0g="
          "chuccle.cachix.org-1:FT8Le4No+sZMyaQEqyWAJdbikbo9CGRQxnFkB9Tl27w="
          "nix-community.cachix.org-1:mB9FSh9qf2dCimDSUo8Zy7bkq5CX+/rkCWyvRCYg3Fs="
        ];

        registry.nixpkgs.flake = inputs.nixpkgs;
        nixPath = singleton "nixpkgs=${inputs.nixpkgs}";
      };
    };
}
