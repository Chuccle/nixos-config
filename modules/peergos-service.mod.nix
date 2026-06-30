{
  flake.nixosModules.peergos-service =
    {
      config,
      lib,
      pkgs,
      ...
    }:
    let
      inherit (lib.lists) singleton;
      inherit (lib.meta) getExe;
      inherit (lib.options) mkOption;
      inherit (lib.strings) escapeShellArgs;
      inherit (lib.types) listOf str;
    in
    {
      options.services.peergos-service = {
        subCommand = mkOption {
          type = str;
          default = "daemon";
          description = "Peergos subcommand to run.";
        };
        extraArgs = mkOption {
          type = listOf str;
          default = [ ];
          description = "Additional arguments passed to the Peergos executable.";
        };
      };

      config = {
        systemd.services.peergos-service = {
          description = "Peergos";
          wantedBy = singleton "multi-user.target";
          after = singleton "network.target";

          serviceConfig = {
            ExecStart = escapeShellArgs (
              singleton (getExe pkgs.peergos)
              ++ singleton config.services.peergos-service.subCommand
              ++ config.services.peergos-service.extraArgs
            );
            StateDirectory = "peergos";
            WorkingDirectory = "/var/lib/peergos";
            Environment = "PEERGOS_PATH=/var/lib/peergos";
            Restart = "on-failure";
          };
        };
      };
    };
}
