# Recipients for `agenix -e <name>.age`, run from this directory. Not a
# module: only the agenix CLI reads it.
let
  # /etc/ssh/ssh_host_ed25519_key.pub on nemoclaw-server-lxc, created with
  #   nix shell nixpkgs#openssh -c ssh-keygen -t ed25519 -N "" -f /etc/ssh/ssh_host_ed25519_key
  nemoclaw-server = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIJLhvoYDtQWjXBHEAtlbdZidnY7V7eQOejRHQjQvBnBE root@nemoclaw-server";

  # ~/.ssh/id_ed25519.pub on the machine that edits secrets.
  user = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIGA10fR7cwOXnDtH5h8mZDYwCdQ4uku4SHbkwCJiA/7C user";
in
{
  "anthropic_api.age".publicKeys = [
    nemoclaw-server
    user
  ];

  "openai_api.age".publicKeys = [
    nemoclaw-server
    user
  ];

  "openrouter_api.age".publicKeys = [
    nemoclaw-server
    user
  ];
}
