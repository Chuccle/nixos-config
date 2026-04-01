{
  perSystem =
    { pkgs, ... }:
    {
      packages.ida-pro = pkgs.callPackage (
        {
          autoPatchelfHook,
          cairo,
          copyDesktopItems,
          curl,
          dbus,
          fetchurl,
          fontconfig,
          freetype,
          glib,
          gtk3,
          lib,
          libGL,
          libdrm,
          libkrb5,
          libsecret,
          libunwind,
          libxkbcommon,
          makeDesktopItem,
          makeWrapper,
          openssl,
          python313,
          qt6,
          stdenv,
          writers,
          zlib,
        }:
        let
          inherit (lib.lists) singleton;
          inherit (lib.licenses) unfree;
          inherit (lib.sourceTypes) binaryNativeCode;
          inherit (lib.strings) readFile;

          python = python313.withPackages (pyPkgs: (singleton pyPkgs.rpyc));
          idaPatch = writers.writePython3Bin "ida-patch" { flakeIgnore = singleton "E501"; } (
            readFile ./ida-patch.py
          );

        in
        stdenv.mkDerivation (finalAttrs: {
          pname = "ida-pro";
          version = "9.2.0.250908";

          src =
            let
              raw = fetchurl {
                url = "https://archive.org/download/ida-pro_91_x64linux/ida-pro_91_x64linux.run";
                sha256 = "8ff08022be3a0ef693a9e3ea01010d1356b26cfdcbbe7fdd68d01b3c9700f9e2";
              };
            in
            pkgs.runCommand "ida-installer.run" { nativeBuildInputs = [ pkgs.patchelf ]; } /* bash */ ''
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
            pkgs.libice
            pkgs.libsm
            pkgs.libx11
            pkgs.libxau
            pkgs.libxcb
            pkgs.libxext
            pkgs.libxi
            pkgs.libxrender
            pkgs.libxcb-image
            pkgs.libxcb-keysyms
            pkgs.libxcb-render-util
            pkgs.libxcb-wm
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
              --prefix QT_PLUGIN_PATH  : $out/opt/ida-pro/plugins/platforms \
              --prefix PYTHONPATH      : $out/opt/ida-pro/idalib/python \
              --prefix PATH            : ${python}/bin:$out/opt/ida-pro \
              --prefix LD_LIBRARY_PATH : $out/lib
            ln -s $out/opt/ida-pro/ida $out/bin/ida

            runHook postInstall
          '';

          postInstall = /* bash */ ''
            # These eglfs platform plugins require Qt5 EGL FS which we don't ship.
            rm -f $out/opt/ida-pro/plugins/platforms/libqeglfs*.so

            # The installer marks everything executable; undo that and selectively
            # restore only the actual executables.
            find $out/opt/ida-pro -type f -exec chmod -x {} \;
            chmod +x $out/opt/ida-pro/{assistant,hv,hvui,ida,idapyswitch,idat,picture_decoder,qwingraph,upg32}

            rm -f $out/opt/ida-pro/{uninstall,Uninstall}*

            ida-patch \
              $out/opt/ida-pro/libida32.so \
              $out/opt/ida-pro/libida.so \
              --output-dir $out/opt/ida-pro

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
      ) { };
    };
}
