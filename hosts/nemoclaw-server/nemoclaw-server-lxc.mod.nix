# Hermes under NVIDIA NemoClaw, as a Proxmox LXC.
#
# NemoClaw runs the OpenShell gateway and every sandbox as Docker containers,
# so this is Docker nested in LXC. On the Proxmox side the container needs:
#
#   pct set <id> --features nesting=1,keyctl=1
#
# nesting lets dockerd create its own namespaces and mount overlayfs; keyctl
# lets runc use the session keyring in an unprivileged container. overlay2
# needs the CT's root on ext4, xfs or ZFS >= 2.2 (Proxmox 8 ships 2.2).
{
  inputs,
  lib,
  self,
  ...
}:
let
  inherit (lib.lists) singleton;

  modules = [
    "${inputs.nixpkgs}/nixos/modules/virtualisation/proxmox-lxc.nix"
    self.nixosModules.agenix
    self.nixosModules.nemoclaw-hermes
    self.nixosModules.security
    self.nixosModules.shell
    self.nixosModules.nix
    self.nixosModules.nuke-default-packages
  ]
  ++ singleton (
    { pkgs, ... }:
    {
      shell.default = "bash";

      environment.systemPackages = singleton pkgs.git;

      # HERMES
      # `inference.local` serves the default route; the three vendors are
      # attached as OpenShell providers, so /model, delegation and fallbacks
      # call them directly.
      services.nemoclaw-hermes = {
        enable = true;

        # Open web for search and browsing. This also permits private ranges,
        # so the VLAN's egress rules are what keep the sandbox off the LAN.
        extraPresets = singleton "personal-open-internet";

        defaultRoute = {
          provider = "anthropic";
          model = "claude-sonnet-5-5";
        };

        # Hermes provider ids: `openai-api` is the direct OpenAI API;
        # plain `openai` is Hermes' alias for OpenRouter.
        hermesSettings = {
          delegation = {
            provider = "openrouter";
            model = "anthropic/claude-sonnet-5.5";
            orchestrator_enabled = true;
            max_spawn_depth = 2;
            # Depth 2 multiplies: at most 3 x 3 concurrent leaves.
            max_concurrent_children = 3;
          };

          # Search uses Hermes' keyless free-tier ring (no backend set);
          # pages are fetched directly over the open-web preset rather than
          # through a third-party extractor.
          web.extract_backend = "native";

          fallback_providers = [
            {
              provider = "anthropic";
              model = "claude-opus-5-5";
            }
            {
              provider = "openai-api";
              model = "gpt-6.1-sol";
            }
            {
              provider = "openrouter";
              model = "anthropic/claude-sonnet-5.5";
            }
          ];
        };
      };

      # The dashboard (18789) and Hermes API (8642) stay on loopback; reach
      # them with `pct enter` or a forward, not through the firewall.
      services.openssh.enable = false;
      services.getty.autologinUser = "root";

      xdg.sounds.enable = false;
      xdg.mime.enable = false;
      xdg.icons.enable = false;
      fonts.fontconfig.enable = false;

      nixpkgs.hostPlatform = "x86_64-linux";
      system.stateVersion = "25.11";
    }
  );
in
{
  flake.nixosConfigurations.nemoclaw-server-lxc = inputs.nixpkgs.lib.nixosSystem {
    inherit modules;
  };

  flake.packages.x86_64-linux.nemoclaw-server-lxc =
    self.nixosConfigurations.nemoclaw-server-lxc.config.system.build.tarball;
}
