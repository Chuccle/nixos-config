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

      # The unit is a real script driven by generated data, not a script
      # assembled by string concatenation: `reconcile.sh` is a reviewable file
      # that shellcheck runs over at build time, and each secret's generator is
      # its own shellcheck'd program. A malformed generator is a build failure,
      # never a surprise at first boot.
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
      # One declaration per credential, reconciled by a single oneshot ordered
      # before anything that consumes them. Two provisioning modes:
      #
      #   generate — a program whose stdout becomes the secret. For values with
      #              no external truth: random keys, tokens, anything the box
      #              can mint for itself.
      #   omitted  — externally provisioned. The module owns the directory and
      #              the permissions, never the content. For values only a
      #              human or another service has.
      #
      # Nothing here ever prompts: boot must stay non-interactive, or an
      # unattended reboot wedges at a password nobody is there to answer.
      # Externally-provisioned secrets are dropped in out-of-band, and their
      # consumers gate on the file existing rather than crash-looping without
      # it.
      #
      # Consumers should read these through systemd `LoadCredential=` rather
      # than opening the path directly, so the plaintext is only ever visible
      # inside the consuming unit's credential namespace.
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
                    description = ''
                      Shell snippet whose stdout becomes the secret, run only
                      when the file is missing or empty. Wrapped in a
                      shellcheck'd program, so a mistake here fails the build
                      rather than the first boot. Leave null for a secret
                      provisioned from outside the configuration.
                    '';
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
                    description = ''
                      Program whose stdout becomes the secret. Defaults to a
                      wrapper around `script`; set it directly to supply a
                      package instead.
                    '';
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
            secrets.files.${name}.path must live under ${cfg.directory} — that
            is the only directory the bootstrap unit is allowed to write to.
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

            # Writes root-owned files under `directory` and hands some of them
            # to a service user, so it keeps CAP_CHOWN/CAP_FOWNER and nothing
            # else. The assertion above guarantees every declared path is under
            # `directory`, which makes this ReadWritePaths list exhaustive.
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
