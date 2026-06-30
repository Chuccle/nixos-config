{
  flake.nixosModules.nuke-default-packages = {
    environment.defaultPackages = [ ];
    environment.stub-ld.enable = false;
  };
}
