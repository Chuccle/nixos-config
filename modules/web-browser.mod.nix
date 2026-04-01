{
  flake.homeModules.web-browser =
    { pkgs, ... }:
    {
      packages = with pkgs; [
        zen-browser
      ];
    };
}
