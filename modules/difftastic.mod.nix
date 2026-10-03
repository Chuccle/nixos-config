{
  flake.homeModules.difftastic =
    { lib, pkgs, ... }:
    let
      inherit (lib.lists) singleton;
    in
    {
      packages = singleton pkgs.difftastic;
    };
}
