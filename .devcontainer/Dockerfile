FROM ghcr.io/lucernae/devcontainer-nix:flake---latest

COPY nix.conf /etc/nix/nix.conf

RUN nix-channel --add https://nixos.org/channels/nixpkgs-unstable nixpkgs \
  && nix-channel --update \
  && nix-env -iA nixpkgs.nix nixpkgs.cacert || true
