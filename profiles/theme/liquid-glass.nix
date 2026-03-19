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
    background = "#09080f";
    foreground = "#ece8f5";
    accent = "#4db8ff";
    border = "#ffffff14";
    surface = "#12101c";
  };
in
{
  theme = {
    meta = {
      name = "liquid-glass";
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
      themeName = "adw-gtk3-dark";
      themePackage = pkgs.adw-gtk3;

      icons = "WhiteSur";
      iconsPackage = pkgs.whitesur-icon-theme;

      cursor = "Bibata-Modern-Ice";
      cursorPackage = pkgs.bibata-cursors;
      cursorSize = 28;
    };

    qt = {
      style = "adwaita-dark";
      stylePackage = pkgs.adwaita-qt;
    };

    terminal = {
      background = "09080f";
      foreground = "ece8f5";
      alpha = "0.76";

      regular = {
        black = "1c1928";
        red = "f87171";
        green = "34d399";
        yellow = "fbbf24";
        blue = "4db8ff";
        magenta = "c084fc";
        cyan = "22d3ee";
        white = "c8c4d8";
      };
      bright = {
        black = "3d3952";
        red = "fca5a5";
        green = "6ee7b7";
        yellow = "fde68a";
        blue = "93c5fd";
        magenta = "d8b4fe";
        cyan = "67e8f9";
        white = "ece8f5";
      };
    };

    compositor = {
      niri = ../../niri/liquid-glass.kdl;
      kwin = {
        effects = {
          desktopSwitching.animation = "slide";
          minimization.animation = "squash";
          windowOpenClose.animation = "glide";
          blur = {
            enable = true;
            strength = 14;
            noiseStrength = 5;
          };
        };
      };
      pantheon = null;
    };

    wallpaper = {
      color = "#09080f";
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
        background:    ${hexToRgba colors.background 0.65};
        color:         #${toHex colors.foreground};
        border-radius: 10px;
      }

      #workspaces button {
        padding:       2px 10px;
        margin:        2px 2px;
        color:         ${hexToRgba colors.foreground 0.4};
        background:    transparent;
        border-radius: 99px;
        transition:    all 0.15s ease;
      }
      #workspaces button.active {
        color:      #${toHex colors.foreground};
        background: ${hexToRgba colors.accent 0.18};
      }
      #workspaces button:hover {
        background: ${hexToRgba colors.foreground 0.08};
      }

      #window {
        color:      ${hexToRgba colors.foreground 0.6};
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
        background:    ${hexToRgba colors.foreground 0.07};
        border-radius: 6px;
        padding:       2px 10px;
        margin:        2px 2px;
      }

      #battery.warning  { color: #fbbf24; }
      #battery.critical { color: #f87171; }

      tooltip {
        background:    ${hexToRgba colors.surface 0.92};
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
        background = "${toHex colors.background}ee";
        text = "${toHex colors.foreground}ff";
        match = "${toHex colors.accent}ff";
        selection = "${toHex colors.accent}33";
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
