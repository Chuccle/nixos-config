{
  projectRootFile = "flake.nix";
  programs = {
    nixfmt.enable = true;
    prettier = {
      enable = true;
      includes = [
        "*.yml"
        "*.yaml"
      ];
    };
  };
}
