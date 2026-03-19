{ pkgs, lib, ... }:
let
  toHex = s: lib.removePrefix "#" s;
  hexToRgba =
    hex: a:
    let
      h = toHex hex;
      r = lib.fromHexString (lib.substring 0 2 h);
      g = lib.fromHexString (lib.substring 2 2 h);
      b = lib.fromHexString (lib.substring 4 2 h);
    in
    "rgba(${toString r}, ${toString g}, ${toString b}, ${toString a})";

  colors = {
    background = "#f6f6f8";
    foreground = "#1c1c1e";
    accent = "#0071e3";
    border = "#00000012";
    surface = "#ffffff";
  };
in
{
  theme = {
    meta = {
      name = "whitesur";
      colorScheme = "BreezeDark";
    };

    inherit colors;

    fonts = {
      sans = {
        name = "Geist";
        size = 11;
      };
      monospace = {
        name = "Geist Mono";
        size = 11;
      };
      packages = with pkgs; [
        geist-font
        fira-code
        cantarell-fonts
        font-awesome
      ];
    };

    gtk = {
      themeName = "WhiteSur-Light";
      themePackage = pkgs.whitesur-gtk-theme;

      icons = "WhiteSur";
      iconsPackage = pkgs.whitesur-icon-theme;

      cursor = "Bibata-Modern-Classic";
      cursorPackage = pkgs.bibata-cursors;
      cursorSize = 28;
    };

    qt = {
      style = "adwaita";
      stylePackage = pkgs.adwaita-qt;
    };

    terminal = {
      background = "f6f6f8";
      foreground = "1c1c1e";
      alpha = "0.88";

      regular = {
        black = "1c1c1e";
        red = "ff3b30";
        green = "34c759";
        yellow = "ff9500";
        blue = "0071e3";
        magenta = "af52de";
        cyan = "32ade6";
        white = "f2f2f7";
      };
      bright = {
        black = "636366";
        red = "ff6961";
        green = "30d158";
        yellow = "ffd60a";
        blue = "409cff";
        magenta = "da8fff";
        cyan = "5ac8f5";
        white = "ffffff";
      };
    };

    compositor = {
      niri = ../../niri/whitesur.kdl;
      kwin = {
        effects = {
          desktopSwitching.animation = "slide";
          minimization.animation = "squash";
          windowOpenClose.animation = "glide";
          blur = {
            enable = true;
            strength = 12;
            noiseStrength = 2;
          };
        };
      };
      pantheon = null;
    };

    wallpaper = {
      color = "#d4e5f7";
      path = null;
    };

    launcher.border = {
      width = 1;
      radius = 12;
    };

    waybar.settings = {
      layer = "top";
      position = "top";
      height = 32;
      spacing = 4;
      margin-top = 6;
      margin-left = 12;
      margin-right = 12;

      modules-left = [
        "niri/workspaces"
        "niri/window"
      ];
      modules-center = [ "clock" ];
      modules-right = [
        "pulseaudio"
        "network"
        "cpu"
        "memory"
        "battery"
        "tray"
      ];

      "niri/workspaces".format = "{index}";
      "niri/window".max-length = 40;

      clock = {
        format = "{:%H:%M}";
        format-alt = "{:%a %d %b  %H:%M}";
      };
      cpu = {
        interval = 5;
        format = " {usage}%";
      };
      memory = {
        interval = 10;
        format = " {percentage}%";
      };
      battery = {
        states = {
          warning = 30;
          critical = 15;
        };
        format = "{icon} {capacity}%";
        format-icons = [
          ""
          ""
          ""
          ""
          ""
        ];
      };
      network = {
        format-wifi = " {signalStrength}%";
        format-ethernet = " {ipaddr}";
        format-disconnected = "󰖪";
      };
      pulseaudio = {
        format = "{icon} {volume}%";
        format-muted = "󰝟";
        format-icons = {
          default = [
            ""
            ""
            ""
          ];
        };
        on-click = "wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle";
      };
      tray.spacing = 8;
    };

    waybar.style = ''
      * {
        font-family:   Geist, sans-serif;
        font-size:     11px;
        min-height:    0;
        border:        none;
        border-radius: 0;
      }

      window#waybar {
        background:    ${hexToRgba colors.surface 0.78};
        color:         #${toHex colors.foreground};
        border-radius: 10px;
      }

      #workspaces button {
        padding:       2px 10px;
        margin:        2px 2px;
        color:         ${hexToRgba colors.foreground 0.35};
        background:    transparent;
        border-radius: 99px;
        transition:    all 0.15s ease;
      }
      #workspaces button.active {
        color:      #${toHex colors.accent};
        background: ${hexToRgba colors.accent 0.10};
      }
      #workspaces button:hover {
        background: ${hexToRgba colors.foreground 0.06};
      }

      #window {
        color:      ${hexToRgba colors.foreground 0.5};
        padding:    0 8px;
        font-style: italic;
      }

      #clock {
        color:       #${toHex colors.foreground};
        font-weight: 600;
        padding:     0 12px;
      }

      #cpu, #memory, #battery, #network, #pulseaudio, #tray {
        color:         #${toHex colors.foreground};
        background:    ${hexToRgba colors.foreground 0.05};
        border-radius: 6px;
        padding:       2px 10px;
        margin:        2px 2px;
      }

      #battery.warning  { color: #f59e0b; }
      #battery.critical { color: #ef4444; }

      tooltip {
        background:    ${hexToRgba colors.surface 0.96};
        border-radius: 8px;
        color:         #${toHex colors.foreground};
      }
    '';

    fuzzel.settings = {
      main = {
        font = "Geist:size=11";
        icon-theme = "WhiteSur";
      };
      colors = {
        background = "${toHex colors.surface}f0"; # near-opaque white
        text = "${toHex colors.foreground}ff";
        match = "${toHex colors.accent}ff";
        selection = "${toHex colors.accent}22"; # lighter tint on white
        selection-text = "${toHex colors.foreground}ff";
        border = "${toHex colors.accent}88";
      };
      border = {
        width = 1;
        radius = 12;
      };
    };
  };
}
