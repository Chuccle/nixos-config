{
  flake.nixosModules.secrets =
    {
      config,
      lib,
      pkgs,
      ...
    }:
    let
      inherit (lib.attrsets) mapAttrsToList;
      inherit (lib.lists) singleton;
      inherit (lib.meta) getExe;
      inherit (lib.modules) mkIf;
      inherit (lib.options) mkOption;
      inherit (lib.strings) fileContents hasPrefix;
      inherit (lib.types)
        attrsOf
        lines
        nullOr
        package
        path
        str
        submodule
        ;

      cfg = config.secrets;

      manifest = pkgs.writers.writeJSON "secrets-manifest.json" (
        mapAttrsToList (
          name:
          {
            generate,
            group,
            mode,
            owner,
            path,
            ...
          }:
          {
            inherit
              group
              mode
              name
              owner
              path
              ;
            generator = if generate == null then null else getExe generate;
          }
        ) cfg.files
      );

      reconcile = pkgs.writeShellApplication {
        name = "secrets-reconcile";
        runtimeInputs = [
          pkgs.coreutils
          pkgs.jq
        ];
        text = fileContents ./secrets/reconcile.sh;
      };
    in
    {
      # PERSISTENT SECRETS
      options.secrets = {
        directory = mkOption {
          type = path;
          default = "/var/lib/secrets";
          description = "Root of the persistent secret store.";
        };

        files = mkOption {
          default = { };
          description = "Secrets to reconcile before dependent services start.";
          type = attrsOf (
            submodule (
              { config, name, ... }:
              {
                options = {
                  path = mkOption {
                    type = path;
                    default = "${cfg.directory}/${name}";
                    defaultText = "\${config.secrets.directory}/\${name}";
                    description = "Where the secret lives on disk.";
                  };

                  script = mkOption {
                    type = nullOr lines;
                    default = null;
                    description = "Shell snippet whose stdout becomes the secret; null for one provisioned by hand.";
                  };

                  generate = mkOption {
                    type = nullOr package;
                    default =
                      if config.script == null then
                        null
                      else
                        pkgs.writeShellApplication {
                          name = "secret-${baseNameOf config.path}";
                          runtimeInputs = [ pkgs.coreutils ];
                          text = config.script;
                        };
                    defaultText = "a shellcheck'd wrapper around `script`";
                    description = "Program whose stdout becomes the secret.";
                  };

                  owner = mkOption {
                    type = str;
                    default = "root";
                    description = "User that owns the secret file.";
                  };

                  group = mkOption {
                    type = str;
                    default = "root";
                    description = "Group that owns the secret file.";
                  };

                  mode = mkOption {
                    type = str;
                    default = "0400";
                    description = "Permissions of the secret file.";
                  };
                };
              }
            )
          );
        };
      };

      config = mkIf (cfg.files != { }) {
        assertions = mapAttrsToList (name: secret: {
          assertion = hasPrefix "${cfg.directory}/" "${secret.path}";
          message = ''
            secrets.files.${name}.path must live under ${cfg.directory}, the
            only directory the bootstrap unit can write to.
          '';
        }) cfg.files;

        systemd.tmpfiles.rules = singleton "d ${cfg.directory} 0700 root root -";

        systemd.services.secrets-bootstrap = {
          description = "Reconcile persistent secrets";

          wantedBy = singleton "multi-user.target";

          after = singleton "systemd-tmpfiles-setup.service";
          requires = singleton "systemd-tmpfiles-setup.service";

          environment.SECRETS_MANIFEST = manifest;

          serviceConfig = {
            Type = "oneshot";
            RemainAfterExit = true;
            UMask = "0077";

            ExecStart = getExe reconcile;

            ProtectSystem = "strict";
            ProtectHome = true;
            PrivateTmp = true;
            NoNewPrivileges = true;
            CapabilityBoundingSet = [
              "CAP_CHOWN"
              "CAP_FOWNER"
            ];
            ReadWritePaths = singleton cfg.directory;

            ProtectKernelTunables = true;
            ProtectKernelModules = true;
            ProtectControlGroups = true;
            ProtectClock = true;
            ProtectHostname = true;
            LockPersonality = true;
            RestrictRealtime = true;
            RestrictSUIDSGID = true;
          };
        };
      };
    };
}
