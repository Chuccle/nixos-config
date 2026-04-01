{
  perSystem =
    { pkgs, lib, ... }:
    let
      inherit (lib.meta) getExe;

      jdk = pkgs.jdk25;
      peergos = pkgs.stdenv.mkDerivation {
        pname = "peergos";
        version = "unstable";

        src = pkgs.fetchFromGitHub {
          owner = "Peergos";
          repo = "web-ui";
          rev = "32a9cef38a5fddc434b9ceaffc465123d7176eaf";
          hash = "sha256-togU8i51D1/tyjAH4gucatHLbAm/XFrvX6qPtpUziak=";
          fetchSubmodules = true;
        };

        nativeBuildInputs = [
          jdk
          pkgs.git
          pkgs.ant
          pkgs.makeWrapper
        ];

        buildPhase = /* bash */ ''
          export HOME=$TMPDIR
          ant dist
        '';

        installPhase = /* bash */ ''
          mkdir -p $out/peergos
          cp -r server/. $out/peergos/

          makeWrapper ${jdk}/bin/java $out/bin/peergos \
            --add-flags "--enable-native-access=ALL-UNNAMED" \
            --add-flags "-jar $out/peergos/Peergos.jar"
        '';

        meta = {
          description = "A p2p, secure file storage, social network and application protocol";
          homepage = "https://github.com/Peergos/web-ui";
          license = lib.licenses.agpl3Only;
          mainProgram = "peergos";
        };
      };
    in
    {
      packages.peergos = peergos;

      apps.peergos = {
        type = "app";
        meta.description = peergos.meta.description;
        program = getExe peergos;
      };
    };
}
