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
  libkrb5,
  libsecret,
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
  libxtst,
  makeDesktopItem,
  makeWrapper,
  nodejs,
  openssl,
  patchelf,
  python313,
  runCommand,
  stdenv,
  xcb-util-cursor,
  zlib,
}:
let
  inherit (lib.licenses) unfree;
  inherit (lib.lists) singleton;
  inherit (lib.sourceTypes) binaryNativeCode;

  version = "9.4.260714";
  releaseUrl = "https://vaclive.party/software/ida-pro/releases/download/${version}";

  installer = fetchurl {
    url = "${releaseUrl}/ida-pro_94_x64linux.run";
    sha256 = "eabb64c3c849d3858759558359e9cebcf17e2a91bcc60523533df8b84462aa54";
  };

  keygen = fetchurl {
    url = "${releaseUrl}/keygen.js";
    sha256 = "cc570f24effc008a4ebd514cc3c4fbb5db05bbdeb7f420b79fdf4ed08a4611e2";
  };

in
stdenv.mkDerivation (finalAttrs: {
  pname = "ida-pro";
  inherit version;

  src = runCommand "ida-installer.run" { nativeBuildInputs = singleton patchelf; } /* bash */ ''
    cp ${installer} $out
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
    nodejs
  ];

  dontUnpack = true;

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
    python313
    libxkbcommon
    openssl.out
    stdenv.cc.cc
    libx11
    libxau
    libxcb
    libxext
    libxi
    libxrender
    libxtst
    libxcbImage
    libxcbKeysyms
    libxcbRenderUtil
    libxcbWm
    xcb-util-cursor
    zlib
    curl.out
  ];

  installPhase = /* bash */ ''
    runHook preInstall

    mkdir -p $out/{bin,lib,opt/ida-pro,homeless-shelter/.local/share/applications}

    HOME=$out/homeless-shelter $src \
      --mode unattended --prefix $out/opt/ida-pro
    rm -rf $out/homeless-shelter

    rm $out/opt/ida-pro/libQt6WaylandEglCompositorHwIntegration.so.6

    rm $out/opt/ida-pro/plugins/platforms/libqeglfs.so
    rm $out/opt/ida-pro/plugins/wayland-shell-integration/libwl-shell-plugin.so

    for lib in $out/opt/ida-pro/*.so $out/opt/ida-pro/*.so.6; do
      ln -s $lib $out/lib/$(basename $lib)
    done

    for needed in libpython3.13.so libcrypto.so libsecret-1.so.0; do
      patchelf --add-needed $needed $out/lib/libida.so
    done

    addAutoPatchelfSearchPath $out/opt/ida-pro

    wrapProgram $out/opt/ida-pro/ida \
      --prefix IDADIR          : $out/opt/ida-pro \
      --prefix QT_PLUGIN_PATH  : $out/opt/ida-pro/plugins \
      --prefix LD_LIBRARY_PATH : $out/lib
    ln -s $out/opt/ida-pro/ida $out/bin/ida

    runHook postInstall
  '';

  postInstall = /* bash */ ''
    find $out/opt/ida-pro -type f -exec sh -c '
      for f; do
        case "$(file -b "$f")" in
          *ELF*executable*) chmod +x "$f" ;;
          *) chmod -x "$f" ;;
        esac
      done
    ' sh {} +

    chmod +x $out/opt/ida-pro/ida

    rm -f $out/opt/ida-pro/{uninstall,Uninstall}*

    cd $out/opt/ida-pro && node ${keygen}

    substituteInPlace $out/opt/ida-pro/cfg/hexrays.cfg \
      --replace "MAX_FUNCSIZE            = 64" "MAX_FUNCSIZE            = 1024"
  '';

  meta = {
    description = "The world's smartest and most feature-full disassembler";
    homepage = "https://hex-rays.com/ida-pro/";
    license = unfree;
    mainProgram = "ida";
    platforms = singleton "x86_64-linux";
    sourceProvenance = singleton binaryNativeCode;
  };
})
