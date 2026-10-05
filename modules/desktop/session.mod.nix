{ self, ... }:
{
  flake.nixosModules.desktop-session =
    {
      config,
      lib,
      ...
    }:
    let
      inherit (lib.meta) getExe;

      ipc = arguments: {
        spawn = [
          (getExe config.programs.dank-material-shell.package)
          "ipc"
        ]
        ++ arguments;
      };
    in
    {
      imports = [
        self.nixosModules.desktop-niri
        self.nixosModules.desktop-dms
        self.nixosModules.desktop-portals
      ];

      config = {
        programs.niri = {
          enable = true;
          useNautilus = false;
        };

        programs.niri.settings.binds = {
          "Mod+Space".action = ipc [
            "spotlight"
            "toggle"
          ];
          "Mod+N".action = ipc [
            "notifications"
            "toggle"
          ];
          "Mod+Comma".action = ipc [
            "settings"
            "toggle"
          ];
          "Mod+P".action = ipc [
            "notepad"
            "toggle"
          ];
          "Mod+Shift+V".action = ipc [
            "clipboard"
            "toggle"
          ];
          "Mod+X".action = ipc [
            "powermenu"
            "toggle"
          ];
          "Mod+Alt+L".action = ipc [
            "lock"
            "lock"
          ];

          "XF86AudioRaiseVolume" = {
            allow-when-locked = true;
            action = ipc [
              "audio"
              "increment"
              "3"
            ];
          };

          "XF86AudioLowerVolume" = {
            allow-when-locked = true;
            action = ipc [
              "audio"
              "decrement"
              "3"
            ];
          };

          "XF86AudioMute" = {
            allow-when-locked = true;
            action = ipc [
              "audio"
              "mute"
            ];
          };

          "XF86AudioMicMute" = {
            allow-when-locked = true;
            action = ipc [
              "audio"
              "micmute"
            ];
          };

          "XF86MonBrightnessUp" = {
            allow-when-locked = true;
            action = ipc [
              "brightness"
              "increment"
              "5"
              ""
            ];
          };

          "XF86MonBrightnessDown" = {
            allow-when-locked = true;
            action = ipc [
              "brightness"
              "decrement"
              "5"
              ""
            ];
          };
        };
      };
    };
}
