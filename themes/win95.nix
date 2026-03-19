{
  niriConfig = ../niri/win95.kdl;

  gtk = {
    theme         = "Chicago95";
    themePackage  = pkgs: pkgs.chicago95;
    icons         = "Chicago95";
    iconsPackage  = pkgs: pkgs.chicago95;
    cursor        = "Chicago95_Cursor_Black";
    cursorPackage = pkgs: pkgs.chicago95;
    cursorSize    = 16;
    font          = { name = "Liberation Sans"; size = 9; };
  };

  qt = {
    style        = "gtk2";
    stylePackage = pkgs: pkgs.libsForQt5.qtstyleplugins;
  };

  fonts = {
    monospace = { name = "Terminus"; size = 10; };
    sans      = { name = "Liberation Sans"; size = 9; };
  };

  colors = {
    background = "#008080";
    foreground = "#ffffff";
    accent     = "#000080";
    border     = "#c0c0c0";
  };

  foot = {
    background = "1c1c1c";
    foreground = "c0c0c0";
    alpha      = "1.0";
    regular = {
      black = "000000"; red     = "800000";
      green = "008000"; yellow  = "808000";
      blue  = "000080"; magenta = "800080";
      cyan  = "008080"; white   = "c0c0c0";
    };
    bright = {
      black = "808080"; red     = "ff0000";
      green = "00ff00"; yellow  = "ffff00";
      blue  = "0000ff"; magenta = "ff00ff";
      cyan  = "00ffff"; white   = "ffffff";
    };
  };

  swaybg = { color = "#008080"; mode = "solid_color"; };
}