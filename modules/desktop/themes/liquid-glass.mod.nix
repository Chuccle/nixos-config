{
  flake.nixosModules.theme-liquid-glass =
    {
      config,
      lib,
      pkgs,
      ...
    }:
    let
      inherit (lib.modules) mkIf mkMerge;
      cfg = config.desktop;
      border = toString (config.theme.borderWidth or 1);
      pad = toString (config.theme.padding or 8);
      radius = toString (config.theme.cornerRadius or 10);
    in
    {
      config = mkIf (cfg.theme == "liquid-glass") (mkMerge [
        {
          environment.systemPackages = with pkgs; [
            whitesur-gtk-theme
            whitesur-icon-theme
            whitesur-cursors
            libsForQt5.qtstyleplugin-kvantum
            kdePackages.qtstyleplugin-kvantum
          ];
        }

        {
          environment.etc."gtk-2.0/gtkrc".text = ''
            gtk-theme-name = "WhiteSur-Dark"
            gtk-icon-theme-name = "WhiteSur-Dark"
            gtk-cursor-theme-name = "WhiteSur-cursors"
            gtk-font-name = "SF Pro Display 11"
          '';
        }

        {
          environment.etc."gtk-3.0/settings.ini".text = ''
            [Settings]
            gtk-theme-name = WhiteSur-Dark
            gtk-icon-theme-name = WhiteSur-Dark
            gtk-cursor-theme-name = WhiteSur-cursors
            gtk-application-prefer-dark-theme = true
            gtk-font-name = SF Pro Display 11
          '';

          environment.etc."gtk-3.0/gtk.css".text = ''
            /* Liquid Glass overlay — appended after WhiteSur-Dark */

            window,
            .background {
              background-color: alpha(@theme_bg_color, 0.72);
            }

            headerbar,
            .titlebar {
              background-color: alpha(@theme_bg_color, 0.55);
              backdrop-filter: blur(24px);
              border-bottom: ${border}px solid alpha(@borders, 0.25);
            }

            popover > contents,
            .popover {
              background-color: alpha(@theme_bg_color, 0.60);
              border-radius: ${radius}px;
              border: ${border}px solid alpha(@borders, 0.20);
            }

            menu,
            .menu {
              background-color: alpha(@theme_bg_color, 0.65);
              border-radius: ${radius}px;
            }
          '';
        }

        (mkIf (cfg.environment == "niri") {
          programs.niri.settings = {
            layout = {
              gaps = config.theme.margin or 8;
              center-focused-column = "never";

              default-column-width.proportion = 0.5;

              border = {
                enable = true;
                width = config.theme.borderWidth or 1;
                active-color = "rgba(255 255 255 0.30)";
                inactive-color = "rgba(255 255 255 0.08)";
              };

              shadow = {
                enable = true;
                blur-radius = 24;
                offset = {
                  x = 0;
                  y = 4;
                };
                color = "rgba(0 0 0 0.45)";
                inactive-color = "rgba(0 0 0 0.25)";
              };
            };

            window-rules = [
              {
                matches = [ { } ];
                geometry-corner-radius = {
                  top-left = config.theme.cornerRadius or 12;
                  top-right = config.theme.cornerRadius or 12;
                  bottom-left = config.theme.cornerRadius or 12;
                  bottom-right = config.theme.cornerRadius or 12;
                };
                clip-to-geometry = true;
              }
            ];

            layer-rules = [
              {
                matches = [ { namespace = "waybar"; } ];
                opacity = 0.88;
              }
              {
                matches = [ { namespace = "notifications"; } ];
                opacity = 0.90;
              }
            ];

            prefer-no-csd = false;
          };

          environment.etc."skel/.config/waybar/style.css".text = ''
            * {
              font-family: "${config.theme.font.sans.name or "sans-serif"}";
              font-size:   ${toString (config.theme.font.size.normal or 14)}px;
              border:      none;
              border-radius: 0;
              min-height:  0;
            }

            window#waybar {
              background-color: transparent;
              color:            rgba(255, 255, 255, 0.90);
            }

            .modules-left,
            .modules-center,
            .modules-right {
              background-color: rgba(20, 20, 28, 0.55);
              backdrop-filter:  blur(28px) saturate(1.6);
              -webkit-backdrop-filter: blur(28px) saturate(1.6);
              border:           ${border}px solid rgba(255, 255, 255, 0.12);
              border-radius:    ${radius}px;
              padding:          4px ${pad}px;
              margin:           6px 4px;
            }

            #workspaces button {
              padding:          2px 8px;
              color:            rgba(255, 255, 255, 0.55);
              background-color: transparent;
              border-radius:    calc(${radius}px - 4px);
              transition:       background-color 150ms, color 150ms;
            }

            #workspaces button.active {
              background-color: rgba(255, 255, 255, 0.18);
              color:            rgba(255, 255, 255, 0.95);
            }

            #workspaces button:hover {
              background-color: rgba(255, 255, 255, 0.10);
              color:            rgba(255, 255, 255, 0.80);
            }

            #clock,
            #battery,
            #cpu,
            #memory,
            #network,
            #pulseaudio,
            #wireplumber,
            #backlight,
            #tray,
            #mode {
              padding:     2px 10px;
              color:       rgba(255, 255, 255, 0.85);
            }

            /* Battery warning states */
            #battery.warning {
              color: rgba(255, 190, 80, 0.95);
            }

            #battery.critical {
              background-color: rgba(220, 50, 50, 0.35);
              color:            rgba(255, 100, 100, 0.95);
            }

            #tray > .passive {
              -gtk-icon-effect: dim;
            }

            #tray > .needs-attention {
              -gtk-icon-effect: highlight;
            }

            tooltip {
              background-color: rgba(20, 20, 28, 0.75);
              border:           ${border}px solid rgba(255, 255, 255, 0.14);
              border-radius:    calc(${radius}px / 2);
              color:            rgba(255, 255, 255, 0.90);
            }
          '';

          environment.etc."skel/.config/waybar/config.jsonc".text = ''
            {
              "layer": "top",
              "position": "top",
              "height": 36,
              "spacing": 4,
              "reload_style_on_change": true,

              "modules-left":   ["niri/workspaces", "niri/window"],
              "modules-center": ["clock"],
              "modules-right":  ["pulseaudio", "network", "cpu", "memory",
                                 "battery", "tray"],

              "niri/workspaces": {
                "format": "{index}"
              },

              "niri/window": {
                "format": "{}",
                "rewrite": {
                  "(.*) - (.*)": "$1"
                }
              },

              "clock": {
                "format": " {:%H:%M}",
                "format-alt": " {:%A, %B %d}",
                "tooltip-format": "<big>{:%Y %B}</big>\n<tt>{calendar}</tt>"
              },

              "cpu": {
                "format": " {usage}%",
                "interval": 5
              },

              "memory": {
                "format": " {percentage}%",
                "interval": 10
              },

              "battery": {
                "states": { "warning": 25, "critical": 10 },
                "format": "{icon} {capacity}%",
                "format-charging": " {capacity}%",
                "format-icons": ["", "", "", "", ""]
              },

              "network": {
                "format-wifi":         " {essid}",
                "format-ethernet":     "󰈀 {ifname}",
                "format-disconnected": "󰤭",
                "tooltip-format":      "{ifname}: {ipaddr}/{cidr}"
              },

              "pulseaudio": {
                "format":        "{icon} {volume}%",
                "format-muted":  "󰝟",
                "format-icons":  { "default": ["", "", ""] },
                "on-click":      "pavucontrol"
              },

              "tray": {
                "spacing": 8
              }
            }
          '';
        })

        (mkIf (cfg.environment == "plasma") {
          environment.sessionVariables.QT_STYLE_OVERRIDE = "kvantum";
          services.desktopManager.plasma6.enableQt5Integration = true;

          environment.etc."skel/.config/kwinrc".text = ''
            [Plugins]
            blurEnabled=true
            contrastEnabled=true
            translucencyEnabled=true
            roundedcornersEnabled=true

            [Effect-blur]
            BlurStrength=12
            NoiseStrength=2

            [Effect-translucency]
            ActiveWindow=88
            InactiveWindow=82
            MoveResize=80
            Dialogs=85
            Menus=75
            DropdownMenus=75
            PopupMenus=75
            Tooltips=80
          '';

          environment.etc."skel/.config/kdeglobals".text = ''
            [General]
            ColorScheme=BreezeDark
            widgetStyle=kvantum

            [KDE]
            LookAndFeelPackage=org.kde.breezedark.desktop
          '';
        })

      ]);
    };
}
