{
  flake.homeModules.desktop-programs = {
    programs.bottom.enable = true;
    programs.nushell.enable = true;

    programs.starship = {
      enable = true;
      integrations.nushell.enable = true;
    };

    programs.zoxide = {
      enable = true;
      integrations.nushell.enable = true;
    };
  };
}
