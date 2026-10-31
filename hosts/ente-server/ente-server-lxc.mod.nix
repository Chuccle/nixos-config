{
  inputs,
  lib,
  self,
  ...
}:
let
  domain = name: "ente-${name}.blorgydoo.com";
in
{
  flake.nixosConfigurations.ente-server-lxc = inputs.nixpkgs.lib.nixosSystem {
    modules = [
      "${inputs.nixpkgs}/nixos/modules/virtualisation/proxmox-lxc.nix"
      self.nixosModules.security
      self.nixosModules.shell
      self.nixosModules.nix
      self.nixosModules.nuke-default-packages
      self.nixosModules.secrets

      (
        {
          config,
          pkgs,
          ...
        }:
        let
          inherit (lib.attrsets)
            attrValues
            filterAttrs
            genAttrs
            mapAttrsToList
            ;
          inherit (lib.generators) toKeyValue;
          inherit (lib.lists) last singleton;
          inherit (lib.meta) getExe getExe';
          inherit (lib.modules) mkForce;
          inherit (lib.strings)
            fileContents
            hasPrefix
            removePrefix
            splitString
            ;
          inherit (lib.trivial) const;

          garage = config.services.garage.settings;
          s3 = config.services.ente.api.settings.s3.b2-eu-cen;

          s3Domain = domain "s3";

          loopback = address: "http://127.0.0.1:${address |> splitString ":" |> last}";

          toNginx = toKeyValue { mkKeyValue = name: value: "${name} ${toString value};"; };

          credential = unit: name: "/run/credentials/${unit}.service/${name}";

          credentialsOf =
            unit:
            config.secrets.files
            |> filterAttrs (name: _: hasPrefix "${unit}/" name)
            |> mapAttrsToList (name: { path, ... }: "${removePrefix "${unit}/" name}:${path}");

          sandbox = {
            ProtectSystem = "strict";
            ProtectHome = true;
            PrivateTmp = true;
            PrivateDevices = true;
            ProtectProc = "invisible";
            ProcSubset = "pid";
            DevicePolicy = "closed";

            NoNewPrivileges = true;
            CapabilityBoundingSet = "";
            RestrictSUIDSGID = true;

            ProtectKernelTunables = true;
            ProtectKernelModules = true;
            ProtectControlGroups = true;
            ProtectClock = true;
            ProtectHostname = true;
            ProtectKernelLogs = true;
            RestrictRealtime = true;

            RestrictNamespaces = true;
            LockPersonality = true;

            RestrictAddressFamilies = [
              "AF_INET"
              "AF_INET6"
              "AF_UNIX"
            ];

            SystemCallFilter = [
              "@system-service"
              "~@privileged"
              "~@resources"
            ];
          };
        in
        {
          shell.default = "bash";

          environment.systemPackages = singleton pkgs.git;

          # GARAGE
          services.garage = {
            enable = true;
            package = pkgs.garage;

            settings = {
              metadata_dir = "/var/lib/garage/meta";
              data_dir = "/var/lib/garage/data";

              replication_factor = 1;

              rpc_bind_addr = "[::]:3901";
              rpc_public_addr = "127.0.0.1:3901";
              rpc_secret_file = credential "garage" "rpc_secret";

              s3_api = {
                s3_region = "garage";
                api_bind_addr = "[::]:3900";
                root_domain = ".s3.garage.localhost";
              };

              s3_web = {
                bind_addr = "[::]:3902";
                root_domain = ".web.garage.localhost";
                index = "index.html";
              };

              admin = {
                api_bind_addr = "[::]:3903";
                admin_token_file = credential "garage" "admin_token";
                metrics_token_file = credential "garage" "metrics_token";
              };
            };
          };

          systemd.services.garage = {
            after = [
              "secrets-bootstrap.service"
              "systemd-tmpfiles-setup.service"
            ];

            requires = singleton "secrets-bootstrap.service";

            serviceConfig = sandbox // {
              LoadCredential = credentialsOf "garage";
            };
          };

          # ENTE
          services.ente = {
            web = {
              enable = true;
              domains = genAttrs [
                "accounts"
                "albums"
                "cast"
                "photos"
              ] domain;
            };

            api = {
              enable = true;
              nginx.enable = true;
              enableLocalDB = true;
              domain = domain "api";

              settings = {
                s3.b2-eu-cen = {
                  are_local_buckets = true;
                  use_path_style_urls = true;
                  endpoint = "https://${s3Domain}";
                  region = garage.s3_api.s3_region;
                  bucket = "ente";

                  key._secret = credential "ente" "s3-access-key-id";
                  secret._secret = credential "ente" "s3-secret-access-key";
                };

                key = {
                  encryption._secret = credential "ente" "encryption-key";
                  hash._secret = credential "ente" "encryption-hash-key";
                };

                jwt.secret._secret = credential "ente" "jwt-secret";
              };
            };
          };

          systemd.services.ente = {
            after = [
              "garage-reconcile.service"
              "garage.service"
              "secrets-bootstrap.service"
            ];

            requires = [
              "garage-reconcile.service"
              "garage.service"
              "secrets-bootstrap.service"
            ];

            serviceConfig.LoadCredential = credentialsOf "ente";
          };

          # SECRETS
          secrets.files =
            let
              openssl = getExe pkgs.openssl;

              enteKey = field: /* bash */ ''
                ${getExe' pkgs.museum "gen-random-keys"} \
                  | ${getExe' pkgs.gnugrep "grep"} '^${field}:' \
                  | ${getExe' pkgs.coreutils "cut"} -d' ' -f2
              '';
            in
            {
              "garage/rpc_secret".script = "${openssl} rand -hex 32";
              "garage/admin_token".script = "${openssl} rand -base64 32";
              "garage/metrics_token".script = "${openssl} rand -base64 32";

              "ente/encryption-key".script = enteKey "key\\.encryption";
              "ente/encryption-hash-key".script = enteKey "key\\.hash";
              "ente/jwt-secret".script = enteKey "jwt\\.secret";

              "ente/s3-access-key-id" = { };
              "ente/s3-secret-access-key" = { };
            };

          # GARAGE RECONCILIATION
          systemd.services.garage-reconcile = {
            description = "Reconcile the Garage layout, key and bucket for Ente";

            after = [
              "garage.service"
              "secrets-bootstrap.service"
            ];

            requires = [
              "garage.service"
              "secrets-bootstrap.service"
            ];

            wantedBy = singleton "multi-user.target";

            serviceConfig = sandbox // {
              Type = "oneshot";
              RemainAfterExit = true;
              UMask = "0077";

              ExecStart =
                getExe
                <| pkgs.writeShellApplication {
                  name = "garage-reconcile";
                  runtimeInputs = [
                    pkgs.awscli2
                    pkgs.coreutils
                    pkgs.curl
                    pkgs.jq
                  ];
                  text = fileContents ./garage-reconcile.sh;
                };

              Restart = "on-failure";
              RestartSec = "10s";

              LoadCredential = singleton "admin_token:${config.secrets.files."garage/admin_token".path}";

              ProtectHome = "tmpfs";

              ReadWritePaths = singleton config.secrets.directory;
            };

            environment = {
              ADMIN_URL = loopback garage.admin.api_bind_addr;
              S3_URL = loopback garage.s3_api.api_bind_addr;

              BUCKET = s3.bucket;
              KEY_NAME = "ente-key";
              DATA_DIR = garage.data_dir;

              CORS_POLICY = pkgs.writers.writeJSON "ente-bucket-cors.json" {
                CORSRules = singleton {
                  AllowedOrigins = singleton "*";
                  AllowedMethods = [
                    "DELETE"
                    "GET"
                    "HEAD"
                    "POST"
                    "PUT"
                  ];
                  AllowedHeaders = singleton "*";
                  ExposeHeaders = singleton "ETag";
                };
              };

              ACCESS_KEY_FILE = config.secrets.files."ente/s3-access-key-id".path;
              SECRET_KEY_FILE = config.secrets.files."ente/s3-secret-access-key".path;

              AWS_DEFAULT_REGION = s3.region;
            };
          };

          # NGINX
          services.nginx = {
            recommendedProxySettings = true;

            virtualHosts =
              (
                genAttrs (
                  attrValues config.services.ente.web.domains
                  ++ [
                    config.services.ente.api.domain
                    s3Domain
                  ]
                )
                <| const {
                  forceSSL = mkForce false;
                  enableACME = mkForce false;
                }
              )
              // {
                ${s3Domain}.locations."/" = {
                  proxyPass = loopback garage.s3_api.api_bind_addr;

                  extraConfig = toNginx {
                    client_max_body_size = 0;
                    proxy_buffering = "off";
                    proxy_request_buffering = "off";
                  };
                };
              };
          };

          networking.firewall.allowedTCPPorts = [
            80
            8080
          ];

          networking.hosts."10.0.60.10" = singleton s3Domain;

          services.openssh.enable = false;
          services.getty.autologinUser = "root";

          xdg.sounds.enable = false;
          xdg.mime.enable = false;
          xdg.icons.enable = false;
          fonts.fontconfig.enable = false;

          nixpkgs.hostPlatform = "x86_64-linux";
          system.stateVersion = "25.11";
        }
      )
    ];
  };

  flake.packages.x86_64-linux.ente-server-lxc =
    self.nixosConfigurations.ente-server-lxc.config.system.build.tarball;
}
