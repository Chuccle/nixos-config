# `@nvidia/openshell-sdk`, which NemoClaw bundles but resolves from GitHub
# Packages (auth-only, even for public reads). Built from the `openshell`
# package's source, so the SDK always matches the gateway: protobuf codegen
# with the npm-shipped `buf`, then `tsc`.
# Installed without its own node_modules, so it resolves `@bufbuild/*` and
# `@connectrpc/*` from the NemoClaw tree it is copied into.
{
  buildNpmPackage,
  jq,
  lib,
  nodejs_22,
  openshell,
}:
let
  inherit (lib.licenses) asl20;
  inherit (lib.lists) singleton;
in
buildNpmPackage (finalAttrs: {
  pname = "openshell-sdk";
  inherit (openshell) src version;

  sourceRoot = "${finalAttrs.src.name}/sdk/typescript";

  nodejs = nodejs_22;
  npmDepsHash = "sha256-Suc0EG8xBOmuNv6qZW8tDpTCw0AtB77DzcXSukB8das=";

  nativeBuildInputs = singleton jq;

  buildPhase = /* bash */ ''
    runHook preBuild
    npm run gen
    npm run build
    runHook postBuild
  '';

  installPhase = /* bash */ ''
    runHook preInstall
    mkdir -p $out
    cp -r README.md dist $out/
    # Upstream stamps the version at publish time; NemoClaw checks the pin.
    jq '.version = "${finalAttrs.version}"' package.json > $out/package.json
    runHook postInstall
  '';

  meta = {
    description = "TypeScript SDK for the OpenShell gateway";
    homepage = "https://github.com/NVIDIA/OpenShell/tree/main/sdk/typescript";
    license = asl20;
  };
})
