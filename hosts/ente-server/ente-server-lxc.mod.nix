{
  inputs,
  lib,
  self,
  ...
}:
let
  inherit (lib.lists) singleton;
  inherit (lib.modules) mkForce;
  modules = [
    "${inputs.nixpkgs}/nixos/modules/virtualisation/proxmox-lxc.nix"
    self.nixosModules.security
    self.nixosModules.shell
    self.nixosModules.nix
    self.nixosModules.nuke-default-packages
  ]
  ++ singleton (
    { pkgs, ... }:
    {
      shell.default = "bash";

      environment.systemPackages = singleton pkgs.git;

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

      services.ente = {
        web = {
          enable = true;
          domains = {
            accounts = "ente-accounts.blorgydoo.com";
            albums = "ente-albums.blorgydoo.com";
            cast = "ente-cast.blorgydoo.com";
            photos = "ente-photos.blorgydoo.com";
          };
        };
        api = {
          enable = true;
          nginx.enable = true;
          enableLocalDB = true;
          domain = "ente-api.blorgydoo.com";
          settings = {
            s3 = {
              b2-eu-cen = {
                are_local_buckets = true;
                use_path_style_urls = true;
                endpoint = "https://ente-s3.blorgydoo.com";
                region = "garage";
                bucket = "ente";
                key._secret = "/run/credentials/ente.service/s3-access-key-id";
                secret._secret = "/run/credentials/ente.service/s3-secret-access-key";
              };
            };
            key = {
              encryption._secret = "/run/credentials/ente.service/encryption-key";
              hash._secret = "/run/credentials/ente.service/encryption-hash-key";
            };
            jwt.secret._secret = "/run/credentials/ente.service/jwt-secret";
          };
        };
      };

      networking.firewall.allowedTCPPorts = [
        80
        8080
        3900
      ];

      systemd.tmpfiles.rules = [
        "d /var/lib/secrets 0700 root root -"
        "d /var/lib/secrets/garage 0700 root root -"
        "d /var/lib/secrets/ente 0700 root root -"
      ];

      systemd.services.bootstrap-secrets = {
        description = "Generate persistent secrets";

        wantedBy = singleton "multi-user.target";

        unitConfig.ConditionPathExists = "!/var/lib/secrets/.secrets-created";

        serviceConfig = {
          Type = "oneshot";
          RemainAfterExit = true;
          Restart = "no";
        };

        script = /* bash */ ''
          set -euo pipefail

          generate_if_missing() {
            local path="$1"
            shift

            if [[ ! -f "$path" ]]; then
              "$@" | tr -d '\n' > "$path"
              chmod 400 "$path"
              chown root:root "$path"
            fi
          }

          generate_if_missing \
            /var/lib/secrets/garage/rpc_secret \
            ${pkgs.openssl}/bin/openssl rand -hex 32

          generate_if_missing \
            /var/lib/secrets/garage/admin_token \
            ${pkgs.openssl}/bin/openssl rand -base64 32

          generate_if_missing \
            /var/lib/secrets/garage/metrics_token \
            ${pkgs.openssl}/bin/openssl rand -base64 32

          if [[ ! -f /var/lib/secrets/ente/encryption-key ]]; then
            KEYS=$(${pkgs.museum}/bin/gen-random-keys)

            printf '%s' \
              "$(echo "$KEYS" | grep '^key\.encryption:' | cut -d' ' -f2)" \
              > /var/lib/secrets/ente/encryption-key

            printf '%s' \
              "$(echo "$KEYS" | grep '^key\.hash:' | cut -d' ' -f2)" \
              > /var/lib/secrets/ente/encryption-hash-key

            printf '%s' \
              "$(echo "$KEYS" | grep '^jwt\.secret:' | cut -d' ' -f2)" \
              > /var/lib/secrets/ente/jwt-secret

            chmod 400 \
              /var/lib/secrets/ente/encryption-key \
              /var/lib/secrets/ente/encryption-hash-key \
              /var/lib/secrets/ente/jwt-secret

            chown root:root \
              /var/lib/secrets/ente/encryption-key \
              /var/lib/secrets/ente/encryption-hash-key \
              /var/lib/secrets/ente/jwt-secret
          fi

          touch /var/lib/secrets/.secrets-created
        '';
      };

      systemd.services.garage-reconcile = {
        description = "Fully idempotent Garage reconciliation";

        after = [ "garage.service" ];
        requires = [ "garage.service" ];
        wantedBy = [ "multi-user.target" ];

        serviceConfig = {
          Type = "oneshot";
          Restart = "on-failure";
        };

        script = ''
          set -euo pipefail

          GARAGE=${pkgs.garage}/bin/garage
          AWS=${pkgs.awscli2}/bin/aws
          DF=${pkgs.coreutils}/bin/df
          AWK=${pkgs.gawk}/bin/awk

          DATA_DIR="/var/lib/garage/data"

          echo "Waiting for Garage..."
          for i in $(seq 1 30); do
            $GARAGE status >/dev/null 2>&1 && break
            sleep 2
          done

          $GARAGE status >/dev/null 2>&1 || {
            echo "Garage not ready"
            exit 1
          }

          NODE_ID=$($GARAGE status | $AWK '$1 ~ /^[0-9a-f]{16,}/ {print $1; exit}')

          echo "Node: $NODE_ID"

          # -----------------------
          # KEY (idempotent)
          # -----------------------
          if ! $GARAGE key list | grep -qF 'ente-key'; then
            KEY_INFO=$($GARAGE key create ente-key)

            ACCESS_KEY=$(echo "$KEY_INFO" | $AWK -F': ' '/Key ID:/ {print $2}')
            SECRET_KEY=$(echo "$KEY_INFO" | $AWK -F': ' '/Secret key:/ {print $2}')

            echo -n "$ACCESS_KEY" > /var/lib/secrets/ente/s3-access-key-id
            echo -n "$SECRET_KEY" > /var/lib/secrets/ente/s3-secret-access-key
          fi

          ACCESS_KEY=$(cat /var/lib/secrets/ente/s3-access-key-id)
          SECRET_KEY=$(cat /var/lib/secrets/ente/s3-secret-access-key)

          # -----------------------
          # BUCKET (idempotent)
          # -----------------------
          $GARAGE bucket create ente || true

          $GARAGE bucket allow \
            --read --write --owner \
            ente \
            --key "$ACCESS_KEY"

          # -----------------------
          # CAPACITY (reconcile)
          # -----------------------
          AVAILABLE_BYTES=$($DF --output=size -B1 "$DATA_DIR" | tail -1)
          USABLE_GIB=$(( AVAILABLE_BYTES * 90 / 100 / 1024 / 1024 / 1024 ))
          DESIRED=$USABLE_GIB"G"

          LAYOUT="$($GARAGE layout show 2>/dev/null || true)"

          if ! echo "$LAYOUT" | grep -q "$NODE_ID"; then
            $GARAGE layout assign -z dc1 -c "$DESIRED" "$NODE_ID"
            LAYOUT="$($GARAGE layout show 2>/dev/null || true)"
          fi

          CURRENT=$(echo "$LAYOUT" | $AWK -v id="$NODE_ID" '
            $1 == id { for (i=1;i<=NF;i++) if ($i ~ /G$/) {print $i; exit} }
          ')

          [ -z "$CURRENT" ] && CURRENT="0G"

          if [ "$CURRENT" != "$DESIRED" ]; then
            $GARAGE layout assign -z dc1 -c "$DESIRED" "$NODE_ID"
            LAYOUT="$($GARAGE layout show 2>/dev/null || true)"
          fi

          if echo "$LAYOUT" | grep -q "STAGED ROLE CHANGES"; then
            CURRENT_VERSION=$(
              echo "$LAYOUT" |
              $AWK -F': ' '/Current cluster layout version/ {gsub(/[^0-9]/,"",$2); print $2}'
            )

            NEXT_VERSION=$((CURRENT_VERSION + 1))

            $GARAGE layout apply --version "$NEXT_VERSION"
          fi

          # -----------------------
          # CORS (always enforce)
          # -----------------------
          export AWS_ACCESS_KEY_ID="$ACCESS_KEY"
          export AWS_SECRET_ACCESS_KEY="$SECRET_KEY"

          $AWS --endpoint-url http://127.0.0.1:3900 s3api put-bucket-cors \
            --bucket ente \
            --cors-configuration '{
              "CORSRules": [{
                "AllowedOrigins": ["*"],
                "AllowedMethods": ["GET", "PUT", "POST", "DELETE"],
                "AllowedHeaders": ["*"],
                "ExposeHeaders":["ETag"]
              }]
            }'

          echo "Garage reconciliation complete"
        '';
      };

      systemd.services.garage = {
        after = [
          "bootstrap-secrets.service"
          "systemd-tmpfiles-setup.service"
        ];
        requires = singleton "bootstrap-secrets.service";
        serviceConfig.LoadCredential = [
          "rpc_secret:/var/lib/secrets/garage/rpc_secret"
          "admin_token:/var/lib/secrets/garage/admin_token"
          "metrics_token:/var/lib/secrets/garage/metrics_token"
        ];
      };

      systemd.services.ente = {
        after = [
          "bootstrap-secrets.service"
          "garage-reconcile.service"
          "garage.service"
        ];
        requires = [
          "bootstrap-secrets.service"
          "garage-reconcile.service"
          "garage.service"
        ];
        serviceConfig.LoadCredential = [
          "jwt-secret:/var/lib/secrets/ente/jwt-secret"
          "encryption-key:/var/lib/secrets/ente/encryption-key"
          "encryption-hash-key:/var/lib/secrets/ente/encryption-hash-key"
          "s3-access-key-id:/var/lib/secrets/ente/s3-access-key-id"
          "s3-secret-access-key:/var/lib/secrets/ente/s3-secret-access-key"
        ];
      };

      # TLS is terminated by a remote reverse proxy lxc on host; ACME runs there
      services.nginx = {
        recommendedProxySettings = true;
        virtualHosts = {
          "ente-accounts.blorgydoo.com".forceSSL = mkForce false;
          "ente-accounts.blorgydoo.com".enableACME = mkForce false;
          "ente-albums.blorgydoo.com".forceSSL = mkForce false;
          "ente-albums.blorgydoo.com".enableACME = mkForce false;
          "ente-cast.blorgydoo.com".forceSSL = mkForce false;
          "ente-cast.blorgydoo.com".enableACME = mkForce false;
          "ente-photos.blorgydoo.com".forceSSL = mkForce false;
          "ente-photos.blorgydoo.com".enableACME = mkForce false;
          "ente-api.blorgydoo.com".forceSSL = mkForce false;
          "ente-api.blorgydoo.com".enableACME = mkForce false;
          "ente-s3.blorgydoo.com".forceSSL = mkForce false;
          "ente-s3.blorgydoo.com".enableACME = mkForce false;
        };
      };

      services.openssh.enable = false;
      services.getty.autologinUser = "root";

      networking.hosts = {
        "10.0.60.10" = [ "ente-s3.blorgydoo.com" ];
      };

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
