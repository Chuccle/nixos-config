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

      mediaBind = arguments: {
        allow-when-locked = true;
        action = ipc arguments;
      };
    in
    {
      imports = [
        self.nixosModules.desktop-niri
        self.nixosModules.desktop-dms
        self.nixosModules.desktop-portals
      ];

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

        "XF86AudioRaiseVolume" = mediaBind [
          "audio"
          "increment"
          "3"
        ];

        "XF86AudioLowerVolume" = mediaBind [
          "audio"
          "decrement"
          "3"
        ];

        "XF86AudioMute" = mediaBind [
          "audio"
          "mute"
        ];

        "XF86AudioMicMute" = mediaBind [
          "audio"
          "micmute"
        ];

        "XF86MonBrightnessUp" = mediaBind [
          "brightness"
          "increment"
          "5"
          ""
        ];

        "XF86MonBrightnessDown" = mediaBind [
          "brightness"
          "decrement"
          "5"
          ""
        ];
      };
    };
}
