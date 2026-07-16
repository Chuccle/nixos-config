{
  autoPatchelfHook,
  cairo,
  copyDesktopItems,
  curl,
  dbus,
  fetchurl,
  file,
  fontconfig,
  freetype,
  glib,
  gtk3,
  lib,
  libdrm,
  libGL,
  libice,
  libkrb5,
  libsecret,
  libsm,
  libunwind,
  libx11,
  libxau,
  libxcb,
  libxcbImage,
  libxcbKeysyms,
  libxcbRenderUtil,
  libxcbWm,
  libxext,
  libxi,
  libxkbcommon,
  libxrender,
  makeDesktopItem,
  makeWrapper,
  openssl,
  patchelf,
  python313,
  qt6,
  runCommand,
  stdenv,
  writers,
  zlib,
}:
let
  inherit (lib.licenses) unfree;
  inherit (lib.lists) singleton;
  inherit (lib.sourceTypes) binaryNativeCode;
  inherit (lib.strings) readFile;

  python = python313.withPackages (pyPkgs: (singleton pyPkgs.rpyc));
  idaPatch = writers.writePython3Bin "ida-patch" { flakeIgnore = singleton "E501"; } (
    readFile ./ida-patch.py
  );

in
stdenv.mkDerivation (finalAttrs: {
  pname = "ida-pro";
  version = "9.3.260213";

  src =
    let
      raw = fetchurl {
        url = "https://vaclive.party/software/ida-pro/releases/download/9.3.260213/ida-pro_93_x64linux.run";
        sha256 = "2ed43ae4bb84d74dcae6f0099210dfa8d61bfea4952f5f9a07a9aae16cb70f82";
      };
    in
    runCommand "ida-installer.run" { nativeBuildInputs = singleton patchelf; } /* bash */ ''
      cp ${raw} $out
      chmod 755 $out
      patchelf --set-interpreter ${stdenv.cc.bintools.dynamicLinker} $out
    '';

  desktopItem = makeDesktopItem {
    name = "IDA Pro";
    exec = "ida";
    icon = ./ida-pro.png;
    comment = finalAttrs.meta.description;
    desktopName = "IDA Pro";
    genericName = "Interactive Disassembler";
    categories = singleton "Development";
    startupWMClass = "IDA";
  };
  desktopItems = singleton finalAttrs.desktopItem;

  nativeBuildInputs = [
    makeWrapper
    copyDesktopItems
    autoPatchelfHook
    file
    idaPatch
    qt6.wrapQtAppsHook
  ];

  # We just get a runfile in $src, so no need to unpack it.
  dontUnpack = true;

  # Add everything to the RPATH, in case IDA decides to dlopen things.
  buildInputs = finalAttrs.runtimeDependencies;
  runtimeDependencies = [
    cairo
    dbus
    fontconfig
    freetype
    glib
    gtk3
    libdrm
    libGL
    libkrb5
    libsecret
    qt6.qtbase
    qt6.qtwayland
    libunwind
    libxkbcommon
    openssl.out
    stdenv.cc.cc
    libice
    libsm
    libx11
    libxau
    libxcb
    libxext
    libxi
    libxrender
    libxcbImage
    libxcbKeysyms
    libxcbRenderUtil
    libxcbWm
    zlib
    curl.out
    python
  ];

  dontWrapQtApps = true;

  installPhase = /* bash */ ''
    runHook preInstall

    mkdir -p $out/{bin,lib,opt/ida-pro,homeless-shelter/.local/share/applications}

    # HOME is set to a throwaway dir for its stray .desktop write.
    HOME=$out/homeless-shelter $src \
      --mode unattended --prefix $out/opt/ida-pro
    rm -rf $out/homeless-shelter

    # Expose IDA's shared libraries so autoPatchelf and wrappers can find them.
    for lib in $out/opt/ida-pro/*.so $out/opt/ida-pro/*.so.6; do
      ln -s $lib $out/lib/$(basename $lib)
    done

    # IDA dlopens these at runtime; make them explicit so autoPatchelf can resolve them.
    for needed in libpython3.13.so libcrypto.so libsecret-1.so.0; do
      patchelf --add-needed $needed $out/lib/libida.so
    done

    addAutoPatchelfSearchPath $out/opt/ida-pro

    wrapProgram $out/opt/ida-pro/ida \
      --prefix IDADIR          : $out/opt/ida-pro \
      --prefix QT_PLUGIN_PATH  : $out/opt/ida-pro/plugins \
      --prefix PYTHONPATH      : $out/opt/ida-pro/idalib/python \
      --prefix PATH            : ${python}/bin:$out/opt/ida-pro \
      --prefix LD_LIBRARY_PATH : $out/lib
    ln -s $out/opt/ida-pro/ida $out/bin/ida

    runHook postInstall
  '';

  postInstall = /* bash */ ''
    # The installer marks everything executable; only real ELF executables
    # should keep that bit (`.so` shared objects are dlopen'd, not run).
    # Detecting via `file` instead of a fixed name list also covers the
    # debug servers and dev tools under dbgsrv/ and tools/.
    find $out/opt/ida-pro -type f -exec sh -c '
      for f; do
        case "$(file -b "$f")" in
          *ELF*executable*) chmod +x "$f" ;;
          *) chmod -x "$f" ;;
        esac
      done
    ' sh {} +

    rm -f $out/opt/ida-pro/{uninstall,Uninstall}*

    # Requires running in current working directory of the ida installation, so we cd into it first
    cd $out/opt/ida-pro && ida-patch --oneshot

    substituteInPlace $out/opt/ida-pro/cfg/hexrays.cfg \
      --replace "MAX_FUNCSIZE            = 64" "MAX_FUNCSIZE            = 1024"
  '';

  meta = {
    description = "The world's smartest and most feature-full disassembler";
    homepage = "https://hex-rays.com/ida-pro/";
    license = unfree;
    mainProgram = "ida";
    platforms = singleton "x86_64-linux"; # Right now, the installation script only supports Linux.
    sourceProvenance = singleton binaryNativeCode;
  };
})
