# Pure KDL generator shared by desktop modules. Imported (not a *.mod.nix) so
# it stays a plain library: `import ../lib/kdl.nix { inherit lib; }`.
#
# A document is an ordered list of nodes, because KDL is ordered and allows
# repeated node names (`window-rule`, `include`, `match`) — neither of which an
# attrset can express. One node is:
#
#   {
#     name = "border";              # required
#     args = [ 2 "#0a84ff" ];       # positional values
#     props = { width = 2; };       # key=value properties
#     children = [ { ... } ];       # nested nodes
#     comment = "why this exists";  # rendered as // lines above the node
#   }
#
# Targets KDL v1, which is what niri's parser (knuffel) accepts: bare
# `true`/`false` rather than v2's `#true`/`#false`.
{ lib }:
let
  inherit (lib) isBool isFloat isInt;
  inherit (lib.attrsets) mapAttrsToList;
  inherit (lib.lists) replicate;
  inherit (lib.strings)
    concatMapStringsSep
    concatStringsSep
    escape
    splitString
    ;

  # isBool is checked first rather than comparing against `true`: statix
  # rewrites `v == true` to `v`, which then coerces every non-boolean.
  value =
    v:
    if isBool v then
      (if v then "true" else "false")
    else if v == null then
      "null"
    else if isInt v || isFloat v then
      toString v
    else
      ''"${escape [ "\\" "\"" ] (toString v)}"'';

  indentOf = level: concatStringsSep "" (replicate (level * 4) " ");

  renderNode =
    level:
    {
      name,
      args ? [ ],
      props ? { },
      children ? [ ],
      comment ? null,
    }:
    let
      pad = indentOf level;

      # Properties are sorted by mapAttrsToList, which is what we want: the
      # generated file should not reshuffle when an unrelated key is added.
      head = concatStringsSep " " (
        [ name ] ++ map value args ++ mapAttrsToList (k: v: "${k}=${value v}") props
      );

      commentLines =
        if comment == null then [ ] else map (line: "${pad}// ${line}") (splitString "\n" comment);

      body =
        if children == [ ] then
          [ "${pad}${head}" ]
        else
          [ "${pad}${head} {" ] ++ map (renderNode (level + 1)) children ++ [ "${pad}}" ];
    in
    concatStringsSep "\n" (commentLines ++ body);
in
{
  # Render a document (list of nodes) to KDL text.
  toKDL = nodes: concatMapStringsSep "\n" (renderNode 0) nodes + "\n";
}
