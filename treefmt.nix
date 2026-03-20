{
  projectRootFile = "flake.nix";
  programs = {
    nixfmt.enable = true;
    kdlfmt.enable = true;
    prettier = {
      enable = true;
      includes = [
        "*.yml"
        "*.yaml"
      ];
    };
  };
}
