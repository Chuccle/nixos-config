{
  coreutils,
  jq,
  niri,
  util-linux,
  writeShellApplication,
}:
writeShellApplication {
  name = "win95-window-action";
  runtimeInputs = [
    coreutils
    jq
    niri
    util-linux
  ];
  text = /* bash */ ''
    ${builtins.readFile ../../shells/win95-window-action.sh}
  '';
}
