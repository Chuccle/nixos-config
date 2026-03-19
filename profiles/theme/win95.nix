{ pkgs, lib, ... }:
let
  toHex = s: lib.removePrefix "#" s;

  colors = {
    background = "#008080";
    foreground = "#ffffff";
    accent = "#000080";
    border = "#c0c0c0";
    surface = "#c0c0c0";
  };
in
{
  theme = {
    meta = {
      name = "win95";
      colorScheme = null;
    };

    inherit colors;

    fonts = {
      sans = {
        name = "Liberation Sans";
        size = 9;
      };
      monospace = {
        name = "Terminus";
        size = 10;
      };
      packages = with pkgs; [
        liberation_ttf
        terminus_font
      ];
    };

    gtk = {
      themeName = "Chicago95";
      themePackage = pkgs.chicago95;
      icons = "Chicago95";
      iconsPackage = pkgs.chicago95;
      cursor = "Chicago95_Cursor_Black";
      cursorPackage = pkgs.chicago95;
      cursorSize = 16;
    };

    qt = {
      style = "gtk2";
      stylePackage = pkgs.libsForQt5.qtstyleplugins;
    };

    terminal = {
      background = "1c1c1c";
      foreground = "c0c0c0";
      alpha = "1.0";
      regular = {
        black = "000000";
        red = "800000";
        green = "008000";
        yellow = "808000";
        blue = "000080";
        magenta = "800080";
        cyan = "008080";
        white = "c0c0c0";
      };
      bright = {
        black = "808080";
        red = "ff0000";
        green = "00ff00";
        yellow = "ffff00";
        blue = "0000ff";
        magenta = "ff00ff";
        cyan = "00ffff";
        white = "ffffff";
      };
    };

    compositor = {
      niri = ../../niri/win95.kdl;
      kwin = {
        effects = {
          desktopSwitching.animation = "off";
          minimization.animation = "off";
          windowOpenClose.animation = "off";
        };
      };
      pantheon = null;
    };

    wallpaper = {
      color = "#008080";
      path = null;
    };

    launcher.border = {
      width = 2;
      radius = 0;
    };

    waybar.settings = {
      layer = "bottom";
      position = "bottom";
      height = 28;
      spacing = 0;
      exclusive = true;

      modules-left = [ "niri/workspaces" ];
      modules-center = [ ];
      modules-right = [
        "cpu"
        "memory"
        "pulseaudio"
        "battery"
        "network"
        "clock"
        "tray"
      ];

      "niri/workspaces" = {
        format = "{index}: {name}";
        format-active = "[{index}: {name}]";
      };

      clock = {
        format = "{:%H:%M}";
        format-alt = "{:%a %d/%m/%Y %H:%M}";
        tooltip = false;
      };

      cpu = {
        interval = 5;
        format = "CPU: {usage}%";
        tooltip = false;
      };
      memory = {
        interval = 10;
        format = "Mem: {percentage}%";
        tooltip = false;
      };

      battery = {
        states = {
          warning = 30;
          critical = 15;
        };
        format = "Bat: {capacity}%";
        format-icons = [
          ""
          ""
          ""
          ""
          ""
        ];
        tooltip = false;
      };

      network = {
        format-wifi = "Net: {signalStrength}%";
        format-ethernet = "Net: {ipaddr}";
        format-disconnected = "Net: off";
        tooltip = false;
      };

      pulseaudio = {
        format = "Vol: {volume}%";
        format-muted = "Vol: mute";
        on-click = "wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle";
        tooltip = false;
      };

      tray.spacing = 4;
    };

    waybar.style = ''
      * {
        font-family:   "Liberation Sans", sans-serif;
        font-size:     9px;
        min-height:    0;
        border:        none;
      }

      window#waybar {
        background: #${toHex colors.surface};
        color:      #${toHex colors.foreground};
        /* Win95 top bevel */
        border-top:   2px solid #ffffff;
        border-left:  2px solid #ffffff;
      }

      #workspaces button {
        padding:       2px 8px;
        margin:        2px 2px;
        color:         #${toHex colors.foreground};
        background:    #${toHex colors.surface};
        /* raised button bevel */
        border-top:    2px solid #ffffff;
        border-left:   2px solid #ffffff;
        border-bottom: 2px solid #808080;
        border-right:  2px solid #808080;
      }

      #workspaces button.active {
        /* pressed/inset bevel — inverted */
        border-top:    2px solid #808080;
        border-left:   2px solid #808080;
        border-bottom: 2px solid #ffffff;
        border-right:  2px solid #ffffff;
        background:    #${toHex colors.surface};
      }

      #workspaces button:hover {
        background: #${toHex colors.surface};
      }

      #clock {
        color:        #${toHex colors.foreground};
        font-weight:  normal;
        padding:      0 8px;
        border-top:   2px solid #808080;
        border-left:  2px solid #808080;
        border-bottom: 2px solid #ffffff;
        border-right:  2px solid #ffffff;
        margin:       2px 2px;
      }

      #cpu, #memory, #battery, #network, #pulseaudio {
        color:        #${toHex colors.foreground};
        background:   #${toHex colors.surface};
        padding:      0 6px;
        margin:       2px 1px;
        border-top:   2px solid #808080;
        border-left:  2px solid #808080;
        border-bottom: 2px solid #ffffff;
        border-right:  2px solid #ffffff;
      }

      #tray {
        padding: 0 4px;
        margin:  2px 2px;
        border-top:   2px solid #808080;
        border-left:  2px solid #808080;
        border-bottom: 2px solid #ffffff;
        border-right:  2px solid #ffffff;
      }

      tooltip {
        background:   #${toHex colors.surface};
        border-top:   2px solid #ffffff;
        border-left:  2px solid #ffffff;
        border-bottom: 2px solid #808080;
        border-right:  2px solid #808080;
        color:        #${toHex colors.foreground};
      }
    '';

    fuzzel.settings = {
      main = {
        font = "Liberation Sans:size=9";
        icon-theme = "Chicago95";
        terminal = "foot";
      };
      colors = {
        background = "${toHex colors.surface}ff";
        text = "${toHex colors.foreground}ff";
        match = "${toHex colors.accent}ff";
        selection = "${toHex colors.accent}ff";
        selection-text = "${toHex colors.foreground}ff";
        border = "${toHex colors.border}ff";
      };
      border = {
        width = 2;
        radius = 0;
      };
    };
  };
}
