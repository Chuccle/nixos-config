{
  flake.nixosModules.greeter =
    {
      config,
      lib,
      pkgs,
      ...
    }:
    let
      inherit (lib.modules) mkDefault mkIf mkMerge;
      inherit (lib.options) mkOption;
      inherit (lib.types) enum nullOr str;

      cfg = config.desktop;
    in
    {
      options.desktop = {
        greeter = mkOption {
          type = nullOr (enum [
            "greetd-tuigreet"
            "lightdm-pantheon"
            "sddm-wayland"
          ]);
          default = null;
          description = ''
            Display manager / greeter to enable.

              "greetd-tuigreet"   — greetd with TUI greeter (Wayland compositors)
              "lightdm-pantheon"  — LightDM with Pantheon greeter (Pantheon DE)
              "sddm-wayland"      — SDDM in Wayland mode (KDE Plasma)

            Each desktop environment sets a sensible default via mkDefault.
            null → no greeter configured by this module.
          '';
          example = "greetd-tuigreet";
        };

        greeterSession = mkOption {
          type = nullOr str;
          default = null;
          description = ''
            Session command passed to greetd-tuigreet (e.g. "niri-session").
            Only relevant when greeter = "greetd-tuigreet".
          '';
          example = "niri-session";
        };

        defaultSession = mkOption {
          type = nullOr str;
          default = null;
          description = ''
            Default session name for SDDM (e.g. "plasma").
            Only relevant when greeter = "sddm-wayland".
          '';
          example = "plasma";
        };
      };

      config = mkIf (cfg.greeter != null) (mkMerge [
        (mkIf (cfg.greeter == "greetd-tuigreet") {
          services.greetd = {
            enable = true;
            settings.default_session = {
              command =
                mkDefault
                <| lib.strings.concatStringsSep " " (
                  [
                    "${lib.getExe pkgs.greetd.tuigreet}"
                    "--time"
                    "--remember"
                  ]
                  ++ lib.lists.optional (cfg.greeterSession != null) "--session ${cfg.greeterSession}"
                );
            };
          };
        })

        (mkIf (cfg.greeter == "lightdm-pantheon") {
          services.xserver.displayManager.lightdm.enable = true;
          services.xserver.displayManager.lightdm.greeters.pantheon.enable = true;
        })

        (mkIf (cfg.greeter == "sddm-wayland") {
          services.displayManager.sddm = {
            enable = true;
            wayland.enable = true;
            defaultSession =
              mkDefault <| lib.strings.optionalString (cfg.defaultSession != null) cfg.defaultSession;
          };
        })
      ]);
    };
}
