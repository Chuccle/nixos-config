{
  desktopModules.niri =
    { lib, pkgs, ... }:
    let
      inherit (lib.meta) getExe';
      inherit (lib.modules) mkDefault;
      inherit (lib.options) mkOption;
      inherit (lib.types)
        float
        int
        str
        submodule
        ;
    in
    {
      # NIRI GLASS
      # Style knobs for the glass look that are DE-specific — niri's own blur
      # and shadow parameters, not `theme.*` fields every adapter reads — but
      # still host-overridable token declarations rather than literals baked
      # into the home module. Same shape as `dmsBar` in shells/dms.mod.nix.
      options.niriShadow = mkOption {
        description = "niri glass-mode window shadow tokens.";
        type = submodule {
          options = {
            softness = mkOption { type = int; };
            spread = mkOption { type = int; };
            offsetX = mkOption { type = int; };
            offsetY = mkOption { type = int; };
            # Hex alpha byte (00-ff) appended to `theme.palette.base.hex`, not a
            # 0-1 float, so it can be spliced directly into the KDL color
            # string without a float->hex conversion helper.
            opacityHex = mkOption { type = str; };
          };
        };
      };

      # niri's blur is parameterised by passes and sample offset rather than a
      # single radius, so `theme.blur.radius` (which Plasma's BlurStrength maps
      # onto directly) has no meaningful translation here. These are declared
      # separately rather than derived from it by an invented formula.
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

      # How much of every animation duration to keep. Below 1.0 is faster than
      # niri's default; this is the single knob that decides whether the
      # session feels immediate or floaty.
      options.niriAnimationSlowdown = mkOption {
        type = float;
        description = "Multiplier applied to every niri animation duration.";
      };

      config = {
        programs.niri.enable = true;

        # niri spawns xwayland-satellite from PATH for X11 apps; without it,
        # Xwayland integration is silently disabled.
        environment.systemPackages = [ pkgs.xwayland-satellite ];

        # `niri-session` (not `niri --session`) runs niri as a systemd user
        # service, which activates graphical-session.target — the target the
        # DMS user service and portals bind to. Launching the bare binary
        # leaves that target inactive and the session empty.
        desktop.sessionCommand = getExe' pkgs.niri "niri-session";

        niriShadow = mkDefault {
          softness = 40;
          spread = 4;
          offsetX = 0;
          offsetY = 8;
          opacityHex = "b3";
        };

        # Three passes at a wide offset is the depth Tahoe's glass reads at;
        # the slight desaturation lift keeps colour behind the glass from
        # going flat, and a trace of noise stops wide blur from banding on a
        # gradient wallpaper.
        niriBlur = mkDefault {
          passes = 3;
          offset = 5.0;
          noise = 0.04;
          saturation = 1.4;
        };

        niriAnimationSlowdown = mkDefault 0.6;
      };
    };

  desktopHomeModules.niri =
    { lib, osConfig, ... }:
    let
      inherit (lib.lists) concatMap optionals singleton;

      inherit (osConfig)
        niriAnimationSlowdown
        niriBlur
        niriShadow
        theme
        ;
      inherit (theme) palette;

      kdl = import ../lib/kdl.nix { inherit lib; };
      inherit (kdl) toKDL;

      glass = theme.blur.enable;

      # NODE HELPERS
      # Thin sugar over the generic node shape so the document below reads as
      # configuration rather than as data-structure construction.
      leaf = name: args: { inherit name args; };
      block = name: children: { inherit name children; };

      # A keybind is a node named for the chord, holding one action node. Mod
      # is Super, which host desktops swallow before it reaches a VM guest
      # window, so every binding is published on Alt as well — generated from
      # one list rather than the two hand-kept copies this used to be.
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
      # DMS generates these snippets and manages them from its settings UI
      # (cursor, alt-tab, live colors, wallpaper blur). Included last so they
      # win over the token defaults above; optional so missing ones are fine.
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
        (block "input" [
          (block "touchpad" [
            (call "tap")
            (call "natural-scroll")
          ])
        ])

        (block "layout" (
          [
            (leaf "gaps" [ theme.padding ])
            (leaf "center-focused-column" [ "never" ])
            (leaf "background-color" [ palette.base.hex ])

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
              (leaf "color" [ "${palette.base.hex}${niriShadow.opacityHex}" ])
            ])
          ]
        ))

        (call "prefer-no-csd")

        {
          name = "animations";
          comment = ''
            Every animation duration scaled by one token. Nothing is switched
            off — motion still shows where a window went — it just resolves
            faster than niri's default.'';
          children = singleton (leaf "slowdown" [ niriAnimationSlowdown ]);
        }
      ]
      ++ optionals glass [
        {
          name = "blur";
          comment = ''
            The global blur parameters. Without this node niri blurs at its own
            defaults and every depth token goes unread.'';
          children = [
            (leaf "passes" [ niriBlur.passes ])
            (leaf "offset" [ niriBlur.offset ])
            (leaf "noise" [ niriBlur.noise ])
            (leaf "saturation" [ niriBlur.saturation ])
          ];
        }

        {
          name = "overview";
          comment = ''
            So zooming out lands on the theme's own base colour rather than
            niri's default grey.'';
          children = singleton (leaf "backdrop-color" [ palette.base.hex ]);
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
              name = "opacity";
              args = singleton theme.blur.opacity;
              comment = ''
                Windows have to be translucent for blur behind them to be
                visible at all; blur.opacity is what every other surface in
                the stack already tracks.'';
            }
            (block "background-effect" [
              (leaf "xray" [ true ])
              (leaf "blur" [ true ])
            ])
          ]
        ))
      ]
      ++ optionals glass [
        {
          name = "window-rule";
          comment = ''
            Media opts back out of the glass: translucency over a moving
            picture reads as a rendering fault, and there is nothing
            meaningful behind a player worth blurring. niri 26.04 has no
            is-fullscreen match property, so this keys on app id.'';
          children = [
            {
              name = "match";
              props."app-id" = "^(mpv|org\\.kde\\.haruna|helium)$";
            }
            (leaf "opacity" [ 1.0 ])
            (block "background-effect" [
              (leaf "blur" [ false ])
              (leaf "xray" [ false ])
            ])
          ];
        }
      ]
      ++ [
        (block "binds" (
          bind "Return" (spawn [ "foot" ])
          ++ bind "D" dmsSpotlight
          ++ bind "Q" (call "close-window")
          ++ bind "Left" (call "focus-column-left")
          ++ bind "Right" (call "focus-column-right")
          ++ bind "Up" (call "focus-window-up")
          ++ bind "Down" (call "focus-window-down")
          ++ workspaceBinds
          ++ [
            (block "Mod+Shift+E" (singleton (call "quit")))
            (block "Print" (singleton (call "screenshot")))
          ]
        ))
      ]
      ++ dmsIncludes;
    in
    {
      # NIRI CONFIG
      # Scrollable-tiling compositor for the Tahoe stack. The whole config is
      # a Nix value rendered by lib/kdl.nix — there is no KDL text in the repo
      # to drift out of sync with the tokens. Routed through rum.desktops.niri
      # so the rendered config.kdl still gets `niri validate -c` at build time.
      rum.desktops.niri.enable = true;
      rum.desktops.niri.config = toKDL document;
    };
}
