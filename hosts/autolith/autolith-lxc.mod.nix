{
  inputs,
  lib,
  self,
  ...
}:
let
  inherit (lib.lists) singleton;
  inherit (lib.strings) fileContents;
  inherit (lib.meta) getExe;

  user = "autolith";
  home = "/var/lib/autolith";

  secretsDir = "/var/lib/secrets/autolith";
  providerEnvFile = "${secretsDir}/providers.env";
  ttydCredentialFile = "${secretsDir}/ttyd-credential";

  # A real path under /run rather than a `tmux -L` named socket (which
  # resolves under the caller's private /tmp): the session unit and the
  # ttyd unit each run with PrivateTmp, so a named-socket handle created by
  # one would be invisible to the other. /run isn't part of that isolation,
  # so an explicit -S here is the only thing both units can actually share.
  tmuxSocket = "/run/autolith/tmux.sock";
  tmuxSessionName = "main";

  ttydPort = 7681;

  modules = [
    "${inputs.nixpkgs}/nixos/modules/virtualisation/proxmox-lxc.nix"
    self.nixosModules.security
    self.nixosModules.shell
    self.nixosModules.nix
    self.nixosModules.nuke-default-packages
    self.nixosModules.secrets
  ]
  ++ singleton (
    { pkgs, ... }:
    let
      autolithPkg = inputs.llm-agents.packages.${pkgs.stdenv.hostPlatform.system}.autolith;
    in
    {
      shell.default = "bash";

      users.groups.${user} = { };
      users.users.${user} = {
        isSystemUser = true;
        group = user;
        inherit home;
        createHome = true;
        homeMode = "0700";
      };

      environment.systemPackages = [
        pkgs.git
        autolithPkg

        # PROVISIONING
        # Interactive, operator-run, never touched at boot — see
        # autolith-keys.sh for why. Gemini's OAuth flow is deliberately not
        # handled here; it's run once from an attached ttyd session instead.
        (pkgs.writeShellApplication {
          name = "autolith-keys";
          runtimeInputs = [
            pkgs.coreutils
            pkgs.systemd
          ];
          runtimeEnv = {
            ENV_FILE = providerEnvFile;
            UNIT = "autolith-session.service";
          };

          text = fileContents ./autolith-keys.sh;
        })
      ];

      # Content comes from `autolith-keys`; the module owns the directory
      # and mode so the file is never left group-readable after a hand
      # edit. The ttyd credential is fully self-provisioned (random,
      # generated at first activation) since there is nothing an operator
      # needs to choose about it.
      secrets.files = {
        "autolith/providers.env".path = providerEnvFile;

        "autolith/ttyd-credential" = {
          path = ttydCredentialFile;
          script = ''
            printf 'admin:%s\n' "$(tr -dc 'A-Za-z0-9' </dev/urandom | head -c 24)"
          '';
        };
      };

      # init.lisp registers Groq/Cerebras as OpenAI-compatible providers
      # from GROQ_API_KEY/CEREBRAS_API_KEY (see the file for why there's no
      # automatic fallback across the resulting ladder — Autolith's
      # provider layer doesn't have one to hook into).
      environment.etc."autolith-init.lisp".source = ./init.lisp;

      systemd.tmpfiles.rules = [
        "d ${home} 0700 ${user} ${user} -"
        "d ${home}/.config 0700 ${user} ${user} -"
        "d ${home}/.config/autolith 0700 ${user} ${user} -"
        "L+ ${home}/.config/autolith/init.lisp - - - - /etc/autolith-init.lisp"
      ];

      # THE AGENT
      # A plain `autolith` invocation is an interactive session, not a
      # daemon — there is no upstream service mode. `tmux new-session -d`
      # starts the session detached and returns almost immediately, but the
      # tmux *server* it spawns keeps running (and stays in this unit's
      # cgroup, so MemoryMax/CPUQuota/TasksMax below still apply to it) —
      # that's what RemainAfterExit is for: the unit is "active" for as
      # long as that server and the autolith process inside it are.
      systemd.services.autolith-session = {
        description = "Autolith agent session (tmux-backed)";

        # The unit carries ConditionPathExists on this, so before the
        # operator has run `autolith-keys` the agent stays cleanly inactive
        # instead of starting with none of Groq/Cerebras registered.
        unitConfig.ConditionPathExists = providerEnvFile;

        after = [
          "secrets-bootstrap.service"
          "network-online.target"
        ];
        wants = singleton "network-online.target";
        wantedBy = singleton "multi-user.target";

        environment = {
          HOME = home;
          XDG_CONFIG_HOME = "${home}/.config";
          XDG_DATA_HOME = "${home}/.local/share";
          XDG_STATE_HOME = "${home}/.local/state";
          XDG_CACHE_HOME = "${home}/.cache";
        };

        serviceConfig = {
          Type = "oneshot";
          RemainAfterExit = true;

          User = user;
          Group = user;
          WorkingDirectory = home;

          EnvironmentFile = providerEnvFile;

          RuntimeDirectory = "autolith";
          RuntimeDirectoryMode = "0750";

          ExecStart = "${pkgs.tmux}/bin/tmux -S ${tmuxSocket} new-session -d -s ${tmuxSessionName} ${getExe autolithPkg}";
          ExecStop = "${pkgs.tmux}/bin/tmux -S ${tmuxSocket} kill-server";

          # Restart only covers ExecStart itself failing (tmux erroring on
          # launch). Once the session is up, RemainAfterExit means systemd
          # no longer watches it: if `autolith` dies inside its pane, tmux
          # is left holding a dead pane and nothing here restarts it — that
          # needs `systemctl restart autolith-session.service` by hand (or
          # attaching over ttyd and re-launching within the same session).
          Restart = "on-failure";
          RestartSec = 5;

          MemoryMax = "1536M";
          MemoryHigh = "1280M";
          CPUQuota = "150%";
          TasksMax = 512;

          ProtectSystem = "strict";
          ProtectHome = true;
          ReadWritePaths = singleton home;
          PrivateTmp = true;
          NoNewPrivileges = true;
          ProtectKernelTunables = true;
          ProtectKernelModules = true;
          ProtectControlGroups = true;
          ProtectClock = true;
          ProtectHostname = true;
          LockPersonality = true;
          RestrictSUIDSGID = true;
        };
      };

      # THE UI
      # No web/mobile client is documented or exists upstream — Autolith
      # bills itself as a terminal agent. ttyd turns the tmux session above
      # into a browser tab (xterm.js), which is what makes it reachable
      # from a phone: every attach/reattach below is `tmux attach-session`
      # against the *same* server, so a dropped connection (phone screen
      # lock, network handover) just reattaches rather than losing state.
      #
      # No TLS here, deliberately: like ZeroClaw's gateway, the only
      # network path to this box is WireGuard (see the ZeroClaw module for
      # that reasoning) — WireGuard is already the encryption boundary, so
      # a self-signed cert on top would add browser warnings without
      # adding real protection. Basic-auth credential is random and
      # generated at first activation, not chosen — see `secrets.files`
      # above.
      systemd.services.autolith-ttyd = {
        description = "Autolith web terminal (ttyd)";

        after = singleton "autolith-session.service";
        bindsTo = singleton "autolith-session.service";
        wantedBy = singleton "multi-user.target";

        unitConfig.ConditionPathExists = ttydCredentialFile;

        serviceConfig = {
          Type = "simple";

          User = user;
          Group = user;

          Restart = "on-failure";
          RestartSec = 5;

          # The credential lives in a root-owned 0400 file; read it into an
          # argv the ttyd child inherits rather than passing it through the
          # unit file (which would land world-readable in the Nix store).
          ExecStart = getExe (
            pkgs.writeShellApplication {
              name = "autolith-ttyd-start";
              runtimeInputs = [
                pkgs.coreutils
                pkgs.ttyd
                pkgs.tmux
              ];
              text = ''
                credential="$(cat ${lib.strings.escapeShellArg ttydCredentialFile})"
                exec ttyd -p ${toString ttydPort} -W -c "$credential" \
                  tmux -S ${tmuxSocket} attach-session -t ${tmuxSessionName}
              '';
            }
          );

          ProtectSystem = "strict";
          ProtectHome = true;
          PrivateTmp = true;
          NoNewPrivileges = true;
          ProtectKernelTunables = true;
          ProtectKernelModules = true;
          ProtectControlGroups = true;
          ProtectClock = true;
          ProtectHostname = true;
          LockPersonality = true;
          RestrictSUIDSGID = true;
        };
      };

      # Reachable over WireGuard only, same as ZeroClaw's box — this is the
      # one port that actually needs a hole, since (unlike ZeroClaw's
      # loopback-only gateway) the whole point is reaching it remotely.
      networking.firewall.allowedTCPPorts = singleton ttydPort;

      services.openssh.enable = false;
      services.getty.autologinUser = "root";

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
  flake.nixosConfigurations.autolith-server-lxc = inputs.nixpkgs.lib.nixosSystem {
    inherit modules;
  };

  flake.packages.x86_64-linux.autolith-server-lxc =
    self.nixosConfigurations.autolith-server-lxc.config.system.build.tarball;
}
