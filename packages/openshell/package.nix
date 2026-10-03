# Modelled on nixpkgs' `pkgs/by-name/op/openshell`, extended to the gateway
# and sandbox supervisor that NemoClaw also needs. Built the way upstream's
# release workflow does (.github/actions/build-rust-binary): workspace version
# stamped into Cargo.toml, supervisor image tag baked in.
#
# One workspace member per build (`crate`), linked together by the CLI build
# through `companions`:
#
#   openshell-server   built alone, without default features: telemetry is a
#                      default feature, and building beside the CLI would
#                      switch it back on (openshell-sdk pulls openshell-core's
#                      defaults). The in-tree compute drivers are kept. The
#                      gateway hands its disabled state to every supervisor.
#   openshell-sandbox  bind-mounted into every sandbox container, whatever its
#                      libc, so it is built through pkgsStatic.
{
  fetchFromGitHub,
  lib,
  nix-update-script,
  pkg-config,
  rustPlatform,
  versionCheckHook,
  z3,

  crate ? "openshell-cli",
  # Builds whose binaries are linked beside the CLI, where NemoClaw looks for
  # them.
  companions ? [ ],
}:
let
  inherit (lib.licenses) asl20;
  inherit (lib.lists) optional singleton;
  inherit (lib.strings) concatMapStrings;

  withServer = crate == "openshell-server";

  binary =
    {
      openshell-cli = "openshell";
      openshell-server = "openshell-gateway";
      openshell-sandbox = "openshell-sandbox";
    }
    .${crate};
in
rustPlatform.buildRustPackage (finalAttrs: {
  pname = "openshell";
  # Must equal the MIN_VERSION = MAX_VERSION pin in NemoClaw's
  # scripts/install-openshell.sh; the nemoclaw package checks this.
  version = "0.0.116";

  src = fetchFromGitHub {
    owner = "NVIDIA";
    repo = "OpenShell";
    tag = "v${finalAttrs.version}";
    hash = "sha256-9YOAkBPFBOhvc3s/0jl0yphjwblONB6rTZXosIydCIg=";
  };

  cargoHash = "sha256-WVoB7tf1ZxjCo/4sRvKRy8yA0M+R+EjZVkbxr3LHGwQ=";

  postPatch = /* bash */ ''
    substituteInPlace Cargo.toml \
      --replace-fail 'version = "0.0.0"' 'version = "${finalAttrs.version}"'
  '';

  cargoBuildFlags = [
    "--package"
    crate
  ];

  buildNoDefaultFeatures = withServer;
  buildFeatures = optional withServer "in-tree-compute-drivers";

  nativeBuildInputs = [ pkg-config ] ++ optional withServer rustPlatform.bindgenHook;

  buildInputs = optional withServer z3;

  env.OPENSHELL_IMAGE_TAG = finalAttrs.version;

  postInstall = concatMapStrings (companion: /* bash */ ''
    ln -s ${companion}/bin/* $out/bin/
  '') companions;

  # The test suites need Docker, Kubernetes or network access.
  doCheck = false;

  nativeInstallCheckInputs = singleton versionCheckHook;
  doInstallCheck = true;
  versionCheckProgram = "${placeholder "out"}/bin/${binary}";

  passthru = {
    inherit crate;
    updateScript = nix-update-script { };
  };

  meta = {
    changelog = "https://github.com/NVIDIA/OpenShell/releases/tag/v${finalAttrs.version}";
    description = "Sandbox runtime and credential-brokering gateway for autonomous agents";
    homepage = "https://github.com/NVIDIA/OpenShell";
    license = asl20;
    mainProgram = binary;
    platforms = singleton "x86_64-linux";
  };
})
