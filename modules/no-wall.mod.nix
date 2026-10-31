{
  flake.nixosModules.no-wall = {
    systemd.suppressedSystemUnits = [
      "systemd-ask-password-wall.path"
      "systemd-ask-password-wall.service"
    ];

    services.logind.settings.Login.WallMessages = false;
  };
}
