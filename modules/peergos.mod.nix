{
  flake.nixosModules.peergos =
    {
      config,
      lib,
      pkgs,
      self,
      ...
    }:
    let
      inherit (lib.meta) getExe;
      inherit (lib.options) mkOption mkEnableOption;
      inherit (lib.strings) escapeShellArgs;
      inherit (lib.types) listOf str port;
      cfg = config.services.peergos;
    in
    {
      options.services.peergos = {
        enable = mkEnableOption "Peergos";

        extraArgs = mkOption {
          type = listOf str;
          default = [ ];
        };

        ports = mkOption {
          type = listOf port;
          default = [
            4001
            8000
          ];
        };
      };

      config = {
        systemd.services.peergos = {
          description = "Peergos";
          wantedBy = [ "multi-user.target" ];
          after = [ "network.target" ];

          serviceConfig = {
            ExecStart = escapeShellArgs ([ (getExe self.packages.${pkgs.system}.peergos) ] ++ cfg.extraArgs);
            DynamicUser = true;
            StateDirectory = "peergos";
            Environment = "PEERGOS_PATH=%S/peergos";
            Restart = "on-failure";
          };
        };

        networking.firewall.allowedTCPPorts = cfg.ports;
      };
    };
}
