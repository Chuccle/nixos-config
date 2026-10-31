{
  perSystem =
    { pkgs, ... }:
    {
      packages.ida-pro-theme = pkgs.fetchFromGitHub {
        owner = "dracula";
        repo = "ida";
        rev = "bfe394d6aa31d40f2d448760cef00ace596b2462";
        hash = "sha256-Usru4URPGUXcF9Asi6Ok/NA9s7IX8S2LhmpigFe/r58=";
      };
    };
}
