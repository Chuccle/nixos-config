{ self, ... }:
{
  flake.nixosModules.desktop-inspection =
    {
      config,
      lib,
      pkgs,
      ...
    }:
    let
      inherit (lib.lists) singleton;
      inherit (lib.meta) getExe';
      inherit (lib.modules) mkIf;
      inherit (lib.options) mkEnableOption mkOption;
      inherit (lib.types) nonEmptyStr;
    in
    {
      options.inspection.enable = mkEnableOption "live ISO inspection";

      options.inspection.publicKey = mkOption {
        type = nonEmptyStr;
        description = "Ephemeral public key for the live ISO inspection guest";
      };

      config = mkIf config.inspection.enable {
        # Explicitly added by the workflow to its frozen ISO source.
        boot.loader.timeout = lib.mkForce 0;

        services.openssh = {
          enable = true;
          settings = {
            PasswordAuthentication = false;
            KbdInteractiveAuthentication = false;
            PermitRootLogin = "no";
            AllowUsers = [ "nixos" ];
          };
        };

        services.qemuGuest.enable = lib.mkForce false;
        services.spice-vdagentd.enable = lib.mkForce false;

        users.users.nixos.openssh.authorizedKeys.keys = singleton config.inspection.publicKey;

        virtualisation.vmware.guest.enable = true;

        environment.sessionVariables.IDA_INSPECTION_INSTALL_DIR = "${
          self.packages.${pkgs.stdenv.hostPlatform.system}.ida-pro
        }/opt/ida-pro";

        environment.systemPackages = [
          pkgs.binutils
          pkgs.dotool
          pkgs.file
          pkgs.glibc.bin
          pkgs.jq
          pkgs.mesa-demos
          pkgs.python3
          pkgs.strace
          pkgs.wayland-utils
        ];

        boot.kernelModules = [ "uinput" ];

        environment.etc."desktop-inspect.py".source = ../../workflow/guest-inspect.py;
        environment.etc."desktop-ida-functional.py".source = ../../workflow/ida-functional.py;

        systemd.user.services.desktop-readiness = {
          description = "Record desktop readiness for ISO inspection";
          path = singleton pkgs.quickshell;
          wantedBy = [
            "default.target"
            "graphical-session.target"
          ];
          partOf = [ "graphical-session.target" ];
          after = [ "graphical-session.target" ];
          serviceConfig.Type = "oneshot";
          serviceConfig.ExecStart = "${getExe' pkgs.python3 "python3"} ${../../workflow/desktop-ready-probe.py}";
        };

        # Input injection is started only for functional checks, then stopped.
        systemd.services.desktop-test-input = {
          environment.DOTOOL_PIPE = "/run/desktop-test-input/input.pipe";
          path = [
            pkgs.coreutils
            pkgs.procps
          ];
          serviceConfig = {
            ExecStart = "${getExe' pkgs.dotool "dotoold"}";
            Group = config.users.users.nixos.group;
            Restart = "on-failure";
            RuntimeDirectory = "desktop-test-input";
            RuntimeDirectoryMode = "0750";
          };
        };
      };
    };
}
