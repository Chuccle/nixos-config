{
  niriConfig = ../niri/liquid-glass.kdl;

  gtk = {
    theme         = "adw-gtk3-dark";
    themePackage  = pkgs: pkgs.adw-gtk3;
    icons         = "Papirus-Dark";
    iconsPackage  = pkgs: pkgs.papirus-icon-theme;
    cursor        = "Bibata-Modern-Ice";
    cursorPackage = pkgs: pkgs.bibata-cursors;
    cursorSize    = 24;
    font          = { name = "Cantarell"; size = 11; };
  };

  qt = { style = "adwaita-dark"; };

  fonts = {
    monospace = { name = "Fira Code"; size = 11; };
    sans      = { name = "Cantarell"; size = 11; };
  };

  colors = {
    background = "#050510";
    foreground = "#e2e8f0";
    accent     = "#7fc8ff";
    border     = "#ffffff18";
  };

  foot = {
    background = "050510";
    foreground = "e2e8f0";
    alpha      = "0.82";
    regular = {
      black = "1e1e2e"; red     = "f87171";
      green = "34d399"; yellow  = "fde68a";
      blue  = "7fc8ff"; magenta = "c4b5fd";
      cyan  = "5ee7ff"; white   = "cbd5e1";
    };
    bright = {
      black = "475569"; red     = "fca5a5";
      green = "6ee7b7"; yellow  = "fef08a";
      blue  = "bae6fd"; magenta = "ddd6fe";
      cyan  = "a5f3fc"; white   = "f1f5f9";
    };
  };

  swaybg = { color = "#050510"; mode = "solid_color"; };
}