# NemoClaw CLI (`nemoclaw`, `nemohermes`) at a pinned tag. Upstream installs
# from a git checkout rather than `npm pack` output: onboarding stages the
# sandbox image build context from the package root, so the whole built tree
# is installed, not just the `files` list.
{
  buildNpmPackage,
  coreutils,
  curl,
  docker-client,
  fetchFromGitHub,
  git,
  lib,
  makeWrapper,
  nix-update-script,
  nodejs_22,
  openshell,
  openshellSdk,
}:
let
  inherit (lib.licenses) asl20;
  inherit (lib.lists) singleton;
  inherit (lib.strings) makeBinPath;
in
buildNpmPackage (finalAttrs: {
  pname = "nemoclaw";
  version = "0.0.130";

  src = fetchFromGitHub {
    owner = "NVIDIA";
    repo = "NemoClaw";
    tag = "v${finalAttrs.version}";
    hash = "sha256-OGcsYJgGvt1PBTyG/xbAKESzYcXxGR9sT2iWLf+g33Y=";
  };

  # Generated with `npm uninstall --package-lock-only` of two packages:
  #   @nvidia/openshell-sdk            resolves from GitHub Packages, which
  #                                    rejects anonymous reads; `openshellSdk`
  #                                    is installed in its place.
  #   @earendil-works/pi-coding-agent  dev-only (`npm run agent`); its bundled
  #                                    shrinkwrap has no integrity hashes, so
  #                                    `fetchNpmDeps` cannot cache it.
  patches = singleton ./lockfile.patch;

  # The build identity falls back to these stamps when there is no `.git`.
  # The revision is the commit the tag points at.
  postPatch = /* bash */ ''
    echo ${finalAttrs.version} > .version
    echo a73099c7735889a78950b6a22ca9ba30c0cf49f5 > .source-revision
  '';

  nodejs = nodejs_22;
  npmDepsHash = "sha256-U9JnRula6w0gR7MOR3/yHearLDa509BKl4r/u9oFW7c=";
  npmBuildScript = "build:cli";

  # Only dev tools have install scripts (prek downloads a binary from GitHub).
  npmRebuildFlags = singleton "--ignore-scripts";

  nativeBuildInputs = singleton makeWrapper;

  # The gateway compatibility container copies `openshell-gateway` into an
  # image, which a Nix-linked binary cannot survive. It only triggers on a
  # host glibc older than the gateway's; pinned off so it never does.
  installPhase = /* bash */ ''
    runHook preInstall

    npm prune --omit=dev --ignore-scripts
    rm -rf test

    mkdir -p $out/lib
    cp -r . $out/lib/nemoclaw
    mkdir -p $out/lib/nemoclaw/node_modules/@nvidia
    cp -r ${openshellSdk} $out/lib/nemoclaw/node_modules/@nvidia/openshell-sdk

    for bin in nemoclaw nemohermes; do
      makeWrapper ${lib.getExe nodejs_22} $out/bin/$bin \
        --add-flags $out/lib/nemoclaw/bin/$bin.js \
        --set-default NEMOCLAW_OPENSHELL_GATEWAY_CONTAINER_PATCH 0 \
        --prefix PATH : ${
          makeBinPath [
            coreutils
            curl
            docker-client
            git
            nodejs_22
            openshell
          ]
        }
    done

    runHook postInstall
  '';

  doInstallCheck = true;
  # NemoClaw supports exactly one OpenShell release; fail the build, not the
  # first onboarding, when the two packages drift apart.
  installCheckPhase = /* bash */ ''
    grep -qx 'MAX_VERSION="${openshell.version}"' $out/lib/nemoclaw/scripts/install-openshell.sh
    grep -qx 'MIN_VERSION="${openshell.version}"' $out/lib/nemoclaw/scripts/install-openshell.sh
    HOME=$TMPDIR NEMOCLAW_GATEWAY_PORT=8080 $out/bin/nemohermes --help | grep -q 'NemoHermes  v${finalAttrs.version}'
    ${lib.getExe nodejs_22} --input-type=module -e \
      "await import('$out/lib/nemoclaw/node_modules/@nvidia/openshell-sdk/dist/index.js')"
  '';

  passthru.updateScript = nix-update-script { };

  meta = {
    description = "NVIDIA NemoClaw: OpenClaw and Hermes agents inside OpenShell sandboxes";
    homepage = "https://github.com/NVIDIA/NemoClaw";
    license = asl20;
    mainProgram = "nemohermes";
    platforms = singleton "x86_64-linux";
  };
})
