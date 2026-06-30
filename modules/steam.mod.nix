{
  flake.nixosModules.steam = {
    allowedUnfreePackageNames = [
      "steam"
      "steam-unwrapped"
      "steam-original"
      "steam-run"
    ];

    programs.steam.enable = true;
  };
}
