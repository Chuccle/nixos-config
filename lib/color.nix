# Pure colour helpers shared by adapters. Imported (not a *.mod.nix) so it stays
# a plain library: `import ../lib/color.nix { inherit lib; }`.
{ lib }:
let
  inherit (lib.lists) foldl';
  inherit (lib.strings)
    removePrefix
    stringToCharacters
    substring
    toLower
    ;

  hexDigits = {
    "0" = 0;
    "1" = 1;
    "2" = 2;
    "3" = 3;
    "4" = 4;
    "5" = 5;
    "6" = 6;
    "7" = 7;
    "8" = 8;
    "9" = 9;
    "a" = 10;
    "b" = 11;
    "c" = 12;
    "d" = 13;
    "e" = 14;
    "f" = 15;
  };

  hexByte = s: foldl' (acc: c: acc * 16 + hexDigits.${c}) 0 (stringToCharacters (toLower s));
in
{
  # "#rrggbb" -> "r,g,b" (decimal triplet, e.g. for KDE colour schemes).
  toRgb =
    hex:
    let
      h = removePrefix "#" hex;
    in
    "${toString (hexByte (substring 0 2 h))},${toString (hexByte (substring 2 2 h))},${
      toString (hexByte (substring 4 2 h))
    }";
}
