{
  desktopModules.niri =
    {
      config,
      lib,
      pkgs,
      ...
    }:
    let
      inherit (lib.attrsets) mapAttrsRecursive;
      inherit (lib.meta) getExe';
      inherit (lib.modules) mkDefault;
      inherit (lib.options) mkOption;
      inherit (lib.types)
        addCheck
        bool
        enum
        float
        int
        listOf
        str
        strMatching
        submodule
        ;

      inherit (config) theme;

      # PER-LEAF DEFAULTS
      defaults = mapAttrsRecursive (_path: mkDefault);
    in
    {
      # NIRI GLASS
      options.niriShadow = mkOption {
        description = "niri glass-mode window shadow tokens.";
        type = submodule {
          options = {
            softness = mkOption { type = int; };
            spread = mkOption { type = int; };
            offsetX = mkOption { type = int; };
            offsetY = mkOption { type = int; };
            opacityHex = mkOption { type = str; };

            inactiveOpacityHex = mkOption { type = str; };
          };
        };
      };

      options.niriBlur = mkOption {
        description = "niri glass-mode background blur tokens.";
        type = submodule {
          options = {
            passes = mkOption { type = int; };
            offset = mkOption { type = float; };
            noise = mkOption { type = float; };
            saturation = mkOption { type = float; };
          };
        };
      };

      # WINDOW MODEL
      options.niriWindows = mkOption {
        description = "niri window-model tokens.";
        type = submodule {
          options = {
            floating = mkOption { type = bool; };

            clientDecorations = mkOption { type = bool; };
          };
        };
      };

      # SESSION INTEGRATION
      options.niriSession = mkOption {
        description = "niri shell, workspaces, and edition shortcuts.";
        type = submodule {
          options = {
            shell = mkOption {
              type = enum [
                "none"
                "dms"
                "win95"
              ];
              default = "none";
            };
            workspaces = mkOption {
              type = listOf (strMatching "[a-z][a-z0-9-]*");
              default = [ ];
            };
            shortcuts = mkOption {
              type = listOf (submodule {
                options = {
                  key = mkOption { type = strMatching "(Alt|Mod)(\\+[A-Za-z0-9]+)+"; };
                  action = mkOption {
                    type = enum [
                      "close-window"
                      "focus-window-previous"
                      "maximize-window-to-edges"
                      "spawn"
                    ];
                  };
                  command = mkOption {
                    type = listOf str;
                    default = [ ];
                  };
                };
              });
              default = [ ];
            };
          };
        };
        default = { };
      };

      options.niriAnimationSlowdown = mkOption {
        type = float;
        description = "Multiplier applied to every niri animation duration.";
      };

      options.niriMouse = mkOption {
        description = "Mouse acceleration and overview hot corners.";
        type = submodule {
          options = {
            accelProfile = mkOption {
              type = enum [
                "adaptive"
                "flat"
              ];
              default = "flat";
            };
            accelSpeed = mkOption {
              type = addCheck float (value: value >= -1.0 && value <= 1.0);
              default = 0.0;
            };
            hotCorners = mkOption {
              type = bool;
              default = false;
            };
          };
        };
        default = { };
      };

      config = {
        programs.niri.enable = true;

        environment.systemPackages = [ pkgs.xwayland-satellite ];

        desktop.sessionCommand = getExe' pkgs.niri "niri-session";

        niriShadow = defaults {
          softness = 40;
          spread = 4;
          offsetX = 0;
          offsetY = 8;
          opacityHex = "b3";
          inactiveOpacityHex = "59";
        };

        niriBlur = defaults {
          passes = 3;
          offset = 5.0;
          noise = 0.0;
          saturation = 1.4;
        };

        niriWindows = defaults {
          floating = false;
          clientDecorations = theme.blur.enable;
        };

        niriSession = { };

        niriAnimationSlowdown = mkDefault 0.6;
      };
    };

  desktopHomeModules.niri =
    {
      lib,
      osConfig,
      pkgs,
      ...
    }:
    let
      inherit (lib.lists)
        concatMap
        optional
        optionals
        singleton
        ;
      inherit (lib.meta) getExe';

      inherit (osConfig)
        niriAnimationSlowdown
        niriBlur
        niriMouse
        niriSession
        niriShadow
        niriWindows
        theme
        ;
      inherit (theme) palette;

      kdl = import ../lib/kdl.nix { inherit lib; };
      inherit (kdl) toKDL;

      glass = theme.blur.enable;

      # NODE HELPERS
      leaf = name: args: { inherit name args; };
      block = name: children: { inherit name children; };

      bind =
        chord: action:
        map (modifier: block "${modifier}+${chord}" (singleton action)) [
          "Mod"
          "Alt"
        ];

      spawn = args: leaf "spawn" args;
      call = name: leaf name [ ];

      dmsSpotlight = spawn [
        "dms"
        "ipc"
        "call"
        "spotlight"
        "toggle"
      ];

      dmsThemeToggle = spawn [
        "dms"
        "ipc"
        "call"
        "theme"
        "toggle"
      ];

      workspaceBinds =
        concatMap
          (index: singleton (block "Mod+${toString index}" (singleton (leaf "focus-workspace" [ index ]))))
          [
            1
            2
            3
            4
          ];

      # DMS INTEGRATION
      dmsIncludes =
        map (name: leaf "include" [ "~/.config/niri/dms/${name}.kdl" ] // { props.optional = true; })
          [
            "alttab"
            "binds"
            "colors"
            "cursor"
            "layout"
            "outputs"
            "windowrules"
            "wpblur"
          ];

      document = [
        (block "hotkey-overlay" [ (call "skip-at-startup") ])
        (block "input" [
          (block "mouse" [
            (leaf "accel-profile" [ niriMouse.accelProfile ])
            (leaf "accel-speed" [ niriMouse.accelSpeed ])
          ])
          (block "touchpad" [
            (call "tap")
            (call "natural-scroll")
          ])
        ])

        (block "gestures" [
          (block "hot-corners" (optional (!niriMouse.hotCorners) (call "off")))
        ])

        (block "layout" (
          [
            (leaf "gaps" [ theme.padding ])
            (leaf "center-focused-column" [ "never" ])
            (leaf "background-color" [ palette.base.hex ])
          ]
          ++ optionals (!glass) [
            (block "border" [
              (leaf "width" [ theme.borderWidth ])
              (leaf "active-color" [ palette.accent.hex ])
              (leaf "inactive-color" [ palette.overlay.hex ])
            ])

            (block "focus-ring" [
              (leaf "width" [ theme.borderWidth ])
              (leaf "active-color" [ palette.accent.hex ])
              (leaf "inactive-color" [ palette.overlay.hex ])
            ])
          ]
          ++ optionals glass [
            {
              name = "border";
              children = singleton (call "off");
            }

            (block "focus-ring" (singleton (call "off")))

            (block "shadow" [
              (call "on")
              (leaf "softness" [ niriShadow.softness ])
              (leaf "spread" [ niriShadow.spread ])
              {
                name = "offset";
                props = {
                  x = niriShadow.offsetX;
                  y = niriShadow.offsetY;
                };
              }
              (leaf "color" [ "${palette.edgeShade.hex}${niriShadow.opacityHex}" ])
              (leaf "inactive-color" [ "${palette.edgeShade.hex}${niriShadow.inactiveOpacityHex}" ])
            ])
          ]
        ))

        {
          name = "animations";
          children = singleton (leaf "slowdown" [ niriAnimationSlowdown ]);
        }
      ]
      ++ optionals (!niriWindows.clientDecorations) [
        (call "prefer-no-csd")
      ]
      ++ map (name: leaf "workspace" [ name ]) niriSession.workspaces
      ++ optionals (niriSession.shell == "dms") [
        {
          name = "window-rule";
          comment = "Give Ark's archive headings and information panel room at 720p.";
          children = [
            {
              name = "match";
              props."app-id" = "^org\\.kde\\.ark$";
            }
            (block "default-column-width" (singleton (leaf "fixed" [ 900 ])))
          ];
        }
      ]
      ++ optionals glass [
        {
          name = "blur";
          children = [
            (leaf "passes" [ niriBlur.passes ])
            (leaf "offset" [ niriBlur.offset ])
            (leaf "noise" [ niriBlur.noise ])
            (leaf "saturation" [ niriBlur.saturation ])
          ];
        }

        {
          name = "overview";
          children = singleton (leaf "backdrop-color" [ palette.base.hex ]);
        }
      ]
      ++ optionals niriWindows.floating [
        {
          name = "window-rule";
          children = singleton (leaf "open-floating" [ true ]);
        }
      ]
      ++ [
        (block "window-rule" (
          [
            (leaf "geometry-corner-radius" [ theme.cornerRadius ])
            (leaf "clip-to-geometry" [ true ])
          ]
          ++ optionals glass [
            {
              name = "background-effect";
              children = [
                (leaf "xray" [ true ])
                (leaf "blur" [ true ])
              ];
            }
          ]
        ))
      ]
      ++ optionals glass [
        {
          name = "window-rule";
          children = [
            {
              name = "match";
              props."app-id" = "^(mpv|org\\.kde\\.haruna|helium)$";
            }
            (block "background-effect" [
              (leaf "blur" [ false ])
              (leaf "xray" [ false ])
            ])
          ];
        }
      ]
      ++ [
        (block "binds" (
          bind "Return" (spawn [ (getExe' pkgs.ghostty "ghostty") ])
          ++ optionals (niriSession.shell == "dms") (bind "D" dmsSpotlight)
          ++ bind "Q" (call "close-window")
          ++ bind "Left" (call "focus-column-left")
          ++ bind "Right" (call "focus-column-right")
          ++ bind "Up" (call "focus-window-up")
          ++ bind "Down" (call "focus-window-down")
          ++ workspaceBinds
          ++ map (
            {
              action,
              command,
              key,
            }:
            block key (singleton (if action == "spawn" then spawn command else call action))
          ) niriSession.shortcuts
          ++ bind "V" (call "toggle-window-floating")
          ++ optionals (niriSession.shell == "dms") [
            (block "Mod+Shift+T" (singleton dmsThemeToggle))
          ]
          ++ [
            (block "Mod+Shift+V" (singleton (call "switch-focus-between-floating-and-tiling")))
            (block "Mod+Shift+E" (singleton (call "quit")))
            (block "Print" (singleton (call "screenshot")))
          ]
        ))
      ]
      ++ optionals (niriSession.shell == "dms") dmsIncludes;
    in
    {
      # NIRI CONFIG
      rum.desktops.niri.enable = true;
      rum.desktops.niri.config = toKDL document;
    };
}
