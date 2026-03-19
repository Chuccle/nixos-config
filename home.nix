{ pkgs, theme, ... }: {
  home.stateVersion = "25.11";

  # ── GTK ─────────────────────────────────────────
  gtk = {
    enable = true;
    theme = {
      name    = theme.gtk.theme;
      package = theme.gtk.themePackage pkgs;
    };
    iconTheme = {
      name    = theme.gtk.icons;
      package = theme.gtk.iconsPackage pkgs;
    };
    cursorTheme = {
      name    = theme.gtk.cursor;
      package = theme.gtk.cursorPackage pkgs;
      size    = theme.gtk.cursorSize;
    };
    font = { inherit (theme.gtk.font) name size; };
  };

  # ── Qt ──────────────────────────────────────────
  qt = {
    enable      = true;
    platformTheme.name = "gtk";
    style = {
      name    = theme.qt.style;
      package = theme.qt.stylePackage pkgs;
    };
  };

  # ── Cursor env (Wayland needs this too) ─────────
  home.pointerCursor = {
    name    = theme.gtk.cursor;
    package = theme.gtk.cursorPackage pkgs;
    size    = theme.gtk.cursorSize;
    gtk.enable = true;
  };

  # ── Fonts ────────────────────────────────────────
  fonts.fontconfig.enable = true;

  # ── foot ────────────────────────────────────────
  programs.foot = {
    enable = true;
    settings = {
      main = {
        font            = "${theme.fonts.monospace.name}:size=${toString theme.fonts.monospace.size}";
        dpi-aware       = "yes";
        pad             = "8x8";
      };
      colors-dark = {
        background      = theme.foot.background;
        foreground      = theme.foot.foreground;
        alpha           = theme.foot.alpha;
        regular0        = theme.foot.regular.black;
        regular1        = theme.foot.regular.red;
        regular2        = theme.foot.regular.green;
        regular3        = theme.foot.regular.yellow;
        regular4        = theme.foot.regular.blue;
        regular5        = theme.foot.regular.magenta;
        regular6        = theme.foot.regular.cyan;
        regular7        = theme.foot.regular.white;
        bright0         = theme.foot.bright.black;
        bright1         = theme.foot.bright.red;
        bright2         = theme.foot.bright.green;
        bright3         = theme.foot.bright.yellow;
        bright4         = theme.foot.bright.blue;
        bright5         = theme.foot.bright.magenta;
        bright6         = theme.foot.bright.cyan;
        bright7         = theme.foot.bright.white;
      };
    };
  };

  # ── fuzzel ───────────────────────────────────────
  programs.fuzzel = {
    enable = true;
    settings = {
      main = {
        font            = "${theme.fonts.sans.name}:size=${toString theme.fonts.sans.size}";
        icon-theme      = theme.gtk.icons;
      };
      colors = {
        background      = "${theme.colors.background}ee";
        text            = "${theme.colors.foreground}ff";
        match           = "${theme.colors.accent}ff";
        selection       = "${theme.colors.accent}33";
        selection-text  = "${theme.colors.foreground}ff";
        border          = "${theme.colors.accent}88";
      };
      border = {
        width  = 1;
        radius = 4;
      };
    };
  };

  # ── niri config ──────────────────────────────────
  xdg.configFile."niri/config.kdl".source = theme.niriConfig;

  # ── packages ─────────────────────────────────────
  home.packages = with pkgs; [
    foot fuzzel waybar swaybg
    wl-clipboard grim slurp
    nushell zoxide
    helix ripgrep fd bat eza

    # win95 theme packages
    chicago95
    # liquid glass theme packages
    adw-gtk3
    papirus-icon-theme
    bibata-cursors
    # fonts
    liberation_ttf
    geist-font
  ];
  
  programs.zoxide  = { enable = true; enableNushellIntegration = true; };
  programs.nushell = { enable = true; };
}