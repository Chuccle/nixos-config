{
  desktopModules.labwc =
    {
      config,
      lib,
      pkgs,
      ...
    }:
    let
      inherit (lib.meta) getExe getExe';
    in
    {
      environment.systemPackages = [
        pkgs.labwc
        pkgs.quickshell
        pkgs.swaybg
      ];

      # WLR_RENDERER_ALLOW_SOFTWARE lets wlroots fall back to llvmpipe, so the
      # stack still comes up in VMs without GPU acceleration (virgl).
      # WLR_NO_HARDWARE_CURSORS: without GPU accel, wlroots still hands the
      # cursor to the virtual GPU's hardware cursor plane, whose format/
      # orientation QEMU's virtual display gets wrong — renders as an
      # upside-down cursor regardless of theme. Forces software cursor
      # compositing instead.
      # XCURSOR_THEME/SIZE: greetd execs this directly with no PAM/login-shell
      # step in between, so the generic `environment.sessionVariables` set in
      # cursor-icons.mod.nix never reaches this process (confirmed live —
      # labwc logged "Environment variable $XCURSOR_THEME not set, ignoring."
      # and fell back to its built-in placeholder cursor). Set explicitly
      # here, same as labwc's own FAQ recommends. All prefixed via `env`
      # (not a wrapper script) because greetd execs the command without a
      # shell.
      desktop.sessionCommand = "${getExe' pkgs.coreutils "env"} WLR_RENDERER_ALLOW_SOFTWARE=1 WLR_NO_HARDWARE_CURSORS=1 XCURSOR_THEME=${config.theme.cursor.name} XCURSOR_SIZE=${toString config.theme.cursor.size} ${getExe pkgs.labwc}";

      # SESSION BASELINE
      # The niri stack gets these via nixpkgs' programs.niri -> wayland-session;
      # labwc has no nixpkgs module, so enable the GPU userspace stack (mesa at
      # /run/opengl-driver — labwc and quickshell need EGL) and polkit here.
      services.graphical-desktop.enable = true;
      security.polkit.enable = true;
    };

  desktopHomeModules.labwc =
    { lib, osConfig, ... }:
    let
      inherit (lib.generators) mkKeyValueDefault toKeyValue;
      inherit (lib.strings) removePrefix;
      inherit (osConfig) theme;
      inherit (theme) palette;

      # labwc themerc uses `key: value`, so generate it with a colon separator
      # rather than ini's `key=value`.
      themerc = toKeyValue { mkKeyValue = mkKeyValueDefault { } ": "; };
    in
    {
      # LABWC CONFIG
      # Stacking Wayland compositor for the Win95 stack. Square corners, classic
      # raised chrome via themerc-override; the quickshell taskbar is autostarted.
      xdg.config.files."labwc/rc.xml".text = /* xml */ ''
        <?xml version="1.0"?>
        <labwc_config>
          <theme>
            <cornerRadius>${toString theme.cornerRadius}</cornerRadius>
            <font place="ActiveWindow">
              <name>${theme.font.sans.name}</name>
              <size>${toString theme.font.size.normal}</size>
            </font>
          </theme>

          <keyboard>
            <keybind key="W-Return">
              <action name="Execute"><command>foot</command></action>
            </keybind>
            <keybind key="W-q">
              <action name="Close"/>
            </keybind>
            <keybind key="A-Tab">
              <action name="NextWindow"/>
            </keybind>
          </keyboard>
        </labwc_config>
      '';

      # THEMERC-OVERRIDE
      # Navy active titlebar, silver chrome, 2px bevels — straight from tokens.
      # Title left-justified and shadows disabled to keep the flat, hard-edged
      # Win95 look rather than a modern soft-blurred titlebar.
      xdg.config.files."labwc/themerc-override".text = themerc {
        "border.width" = theme.borderWidth;
        "padding.height" = theme.padding;

        "window.label.text.justify" = "Left";

        "window.active.title.bg.color" = palette.accent;
        "window.active.label.text.color" = palette.accentText;
        "window.active.border.color" = palette.muted;

        "window.inactive.title.bg.color" = palette.muted;
        "window.inactive.label.text.color" = palette.subtext;
        "window.inactive.border.color" = palette.muted;

        "window.active.button.unpressed.image.color" = palette.accentText;
        "window.inactive.button.unpressed.image.color" = palette.subtext;
        "window.button.hover.bg.color" = palette.overlay;
        "window.button.hover.bg.corner-radius" = theme.cornerRadius;

        "window.active.shadow.size" = 0;
        "window.inactive.shadow.size" = 0;

        "menu.items.bg.color" = palette.surface;
        "menu.items.text.color" = palette.text;
        "menu.items.active.bg.color" = palette.accent;
        "menu.items.active.text.color" = palette.accentText;

        "osd.bg.color" = palette.surface;
        "osd.border.color" = palette.muted;
        "osd.border.width" = theme.borderWidth;
        "osd.label.text.color" = palette.text;
      };

      # AUTOSTART
      # Sourced by labwc via sh, so no executable bit needed. Brings up the
      # taskbar and paints the classic teal desktop.
      xdg.config.files."labwc/autostart".text = /* bash */ ''
        quickshell -c win95 &
        swaybg -c ${removePrefix "#" palette.base} &
      '';
    };
}
