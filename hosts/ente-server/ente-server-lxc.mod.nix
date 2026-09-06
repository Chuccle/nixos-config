{
  inputs,
  lib,
  self,
  ...
}:
let
  inherit (lib.attrsets) listToAttrs nameValuePair;
  inherit (lib.lists) singleton;
  inherit (lib.modules) mkForce;

  # PUBLIC NAMES
  # One source of truth for every hostname this box answers to. `ente.web`
  # takes the four below by attribute name, and the nginx server blocks are
  # generated from the full set — so adding a name is a one-line change that
  # cannot leave the two out of sync. The bucket's CORS policy no longer
  # derives from this list; see corsPolicy below for why.
  domain = name: "ente-${name}.blorgydoo.com";

  webDomains = {
    accounts = domain "accounts";
    albums = domain "albums";
    cast = domain "cast";
    photos = domain "photos";
  };

  apiDomain = domain "api";
  s3Domain = domain "s3";

  proxiedDomains = lib.attrValues webDomains ++ [
    apiDomain
    s3Domain
  ];

  # Garage, as reached from inside this container. The S3 API is also exposed
  # through nginx under `s3Domain` for the reverse proxy's benefit; the admin
  # API never is — it hands out secret access keys.
  garageS3 = "http://127.0.0.1:3900";
  garageAdmin = "http://127.0.0.1:3903";

  bucket = "ente";
  keyName = "ente-key";

  # The reverse-proxy LXC that terminates TLS for every name above.
  reverseProxy = "10.0.60.10";

  modules = [
    "${inputs.nixpkgs}/nixos/modules/virtualisation/proxmox-lxc.nix"
    self.nixosModules.security
    self.nixosModules.shell
    self.nixosModules.nix
    self.nixosModules.nuke-default-packages
    self.nixosModules.secrets
  ]
  ++ singleton (
    {
      config,
      pkgs,
      ...
    }:
    let
      inherit (lib.meta) getExe getExe';
      inherit (lib.strings) fileContents;

      secretPath = name: config.secrets.files.${name}.path;

      # The reconcile logic lives in a real file rather than a Nix string:
      # writeShellApplication runs shellcheck over it at build time, so a
      # quoting mistake is a build failure instead of a 3am unit failure.
      garageReconcile = pkgs.writeShellApplication {
        name = "garage-reconcile";
        runtimeInputs = [
          pkgs.awscli2
          pkgs.coreutils
          pkgs.curl
          pkgs.jq
        ];
        text = fileContents ./garage-reconcile.sh;
      };

      # Wildcarded rather than enumerated: this endpoint carries no ambient
      # authority for CORS to gate (auth is entirely in the presigned query
      # string, no cookies involved, objects are end-to-end encrypted), and
      # an enumerated list is brittle in exactly the way that broke desktop
      # downloads once already — an origin missing from the list fails as an
      # opaque browser-side TypeError with no status, not a diagnosable 403.
      corsPolicy = pkgs.writers.writeJSON "ente-bucket-cors.json" {
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
    in
    {
      shell.default = "bash";

      environment.systemPackages = singleton pkgs.git;

      # ------------------------------------------------------------------
      # Garage
      # ------------------------------------------------------------------

      services.garage = {
        enable = true;
        package = pkgs.garage;

        settings = {
          metadata_dir = "/var/lib/garage/meta";
          data_dir = "/var/lib/garage/data";

          replication_factor = 1;

          rpc_bind_addr = "[::]:3901";
          rpc_public_addr = "127.0.0.1:3901";
          rpc_secret_file = "/run/credentials/garage.service/rpc_secret";

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
            admin_token_file = "/run/credentials/garage.service/admin_token";
            metrics_token_file = "/run/credentials/garage.service/metrics_token";
          };
        };
      };

      # ------------------------------------------------------------------
      # Ente
      # ------------------------------------------------------------------

      services.ente = {
        web = {
          enable = true;
          domains = webDomains;
        };

        api = {
          enable = true;
          nginx.enable = true;
          enableLocalDB = true;
          domain = apiDomain;

          settings = {
            s3.b2-eu-cen = {
              are_local_buckets = true;
              use_path_style_urls = true;
              endpoint = "https://${s3Domain}";
              region = config.services.garage.settings.s3_api.s3_region;
              inherit bucket;

              key._secret = "/run/credentials/ente.service/s3-access-key-id";
              secret._secret = "/run/credentials/ente.service/s3-secret-access-key";
            };

            key = {
              encryption._secret = "/run/credentials/ente.service/encryption-key";
              hash._secret = "/run/credentials/ente.service/encryption-hash-key";
            };

            jwt.secret._secret = "/run/credentials/ente.service/jwt-secret";
          };
        };
      };

      # ------------------------------------------------------------------
      # Firewall
      #
      # Only nginx. Garage's own ports — S3 (3900), RPC (3901), web (3902) and
      # admin (3903) — stay closed and are reached over loopback; the admin
      # API in particular can reveal secret access keys, so it must never be
      # routable. S3 traffic from outside arrives through the `s3Domain`
      # server block below instead.
      # ------------------------------------------------------------------

      networking.firewall.allowedTCPPorts = [
        80
        8080
      ];

      # ------------------------------------------------------------------
      # Persistent secrets
      #
      # All self-minted, so a fresh container provisions itself with no
      # operator step. The two S3 credentials are declared without a generator
      # because Garage alone can produce them — garage-reconcile writes them.
      # ------------------------------------------------------------------

      secrets.files =
        let
          openssl = getExe pkgs.openssl;

          # gen-random-keys prints one `<name>: <value>` line per key, and the
          # values are independent of each other — so taking one line from its
          # own invocation is equivalent to sharing one, and keeps each secret
          # a self-contained declaration.
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

      # ------------------------------------------------------------------
      # Garage reconciliation
      #
      # Idempotent, and driven by Garage's admin API rather than by scraping
      # the CLI's human-readable output — every value below is read out of
      # JSON with jq, so a cosmetic change to `garage status` can no longer
      # silently break provisioning.
      # ------------------------------------------------------------------

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

        serviceConfig = {
          Type = "oneshot";
          RemainAfterExit = true;
          UMask = "0077";

          ExecStart = getExe garageReconcile;

          Restart = "on-failure";
          RestartSec = "10s";

          LoadCredential = singleton "admin_token:${secretPath "garage/admin_token"}";

          # The script only ever creates root-owned files, so it needs no
          # capabilities at all — the secret store is the single writable path.
          # ProtectHome is tmpfs rather than true because awscli resolves
          # ~/.aws before deciding it has no config to read, and `true` leaves
          # those paths mode 000 rather than merely empty.
          ProtectSystem = "strict";
          ProtectHome = "tmpfs";
          PrivateTmp = true;
          PrivateDevices = true;
          ProtectProc = "invisible";
          ProcSubset = "pid";
          DevicePolicy = "closed";

          ReadWritePaths = singleton config.secrets.directory;

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

        # Config reaches the script as environment, never as interpolated
        # text: the script is a real reviewable file that shellcheck runs over
        # at build time, and nothing in it is assembled by Nix.
        environment = {
          ADMIN_URL = garageAdmin;
          S3_URL = garageS3;

          BUCKET = bucket;
          KEY_NAME = keyName;
          CORS_POLICY = corsPolicy;
          DATA_DIR = config.services.garage.settings.data_dir;

          ACCESS_KEY_FILE = secretPath "ente/s3-access-key-id";
          SECRET_KEY_FILE = secretPath "ente/s3-secret-access-key";

          AWS_DEFAULT_REGION = config.services.garage.settings.s3_api.s3_region;
        };
      };

      # ------------------------------------------------------------------
      # Garage credentials + hardening
      #
      # The upstream module ships no sandboxing, so the rest of this host's
      # profile is applied here. Garage keeps CAP_* empty but needs real
      # filesystem access for its metadata and data directories, which
      # StateDirectory already grants.
      # ------------------------------------------------------------------

      systemd.services.garage = {
        after = [
          "secrets-bootstrap.service"
          "systemd-tmpfiles-setup.service"
        ];

        requires = singleton "secrets-bootstrap.service";

        serviceConfig = {
          LoadCredential = map (credential: "${credential}:${secretPath "garage/${credential}"}") [
            "admin_token"
            "metrics_token"
            "rpc_secret"
          ];

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
      };

      # ------------------------------------------------------------------
      # Ente credentials + dependencies
      # ------------------------------------------------------------------

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

        serviceConfig.LoadCredential =
          map (credential: "${credential}:${secretPath "ente/${credential}"}")
            [
              "encryption-hash-key"
              "encryption-key"
              "jwt-secret"
              "s3-access-key-id"
              "s3-secret-access-key"
            ];
      };

      # ------------------------------------------------------------------
      # Nginx
      #
      # TLS terminates on the reverse-proxy LXC, which is also where ACME
      # runs, so every vhost the ente module generates has its forceSSL /
      # enableACME defaults forced back off.
      #
      # The s3 vhost is ours rather than the ente module's. Ente signs upload
      # URLs for the public `s3Domain` name, clients resolve that to the
      # reverse proxy, and the proxy forwards here — so this box needs a
      # server block that actually answers for it. Previously the name was
      # declared with no locations at all, which produced an empty server
      # block that could only 404.
      # ------------------------------------------------------------------

      services.nginx = {
        recommendedProxySettings = true;

        virtualHosts =
          listToAttrs (
            map (
              name:
              nameValuePair name {
                forceSSL = mkForce false;
                enableACME = mkForce false;
              }
            ) proxiedDomains
          )
          // {
            ${s3Domain}.locations."/" = {
              proxyPass = garageS3;

              # Photo and video uploads stream straight through to Garage:
              # buffering them would spool whole originals to disk first, and
              # the default 1M body cap would reject anything real.
              extraConfig = ''
                client_max_body_size 0;
                proxy_request_buffering off;
                proxy_buffering off;
              '';
            };
          };
      };

      # ------------------------------------------------------------------
      # Misc
      # ------------------------------------------------------------------

      services.openssh.enable = false;
      services.getty.autologinUser = "root";

      # Ente signs S3 URLs for the public name, so this box has to resolve
      # that name to something which routes back to Garage — the same reverse
      # proxy external clients use.
      networking.hosts.${reverseProxy} = singleton s3Domain;

      xdg.sounds.enable = false;
      xdg.mime.enable = false;
      xdg.icons.enable = false;
      fonts.fontconfig.enable = false;

      nixpkgs.hostPlatform = "x86_64-linux";
      system.stateVersion = "25.11";
    }
  );
in
{
  flake.nixosConfigurations.ente-server-lxc = inputs.nixpkgs.lib.nixosSystem {
    inherit modules;
  };

  flake.packages.x86_64-linux.ente-server-lxc =
    self.nixosConfigurations.ente-server-lxc.config.system.build.tarball;
}
