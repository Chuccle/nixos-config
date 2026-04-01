{
  flake.homeModules.zoxide = {
    programs.zoxide = {
      enable = true;
      integrations.nushell.enable = true;
    };
  };
}
