{ inputs, ... }:
{
  flake.nixosModules.secure-boot =
    {
      config,
      lib,
      pkgs,
      ...
    }:
    let
      inherit (lib.lists) singleton;
      inherit (lib.modules) mkForce mkIf;
    in
    {
      imports = singleton inputs.lanzaboote.nixosModules.lanzaboote;

      config = {
        environment.systemPackages = singleton pkgs.sbctl;

        boot.loader.systemd-boot.enable = mkIf config.boot.lanzaboote.enable <| mkForce false;
        boot.lanzaboote.pkiBundle = "/var/lib/sbctl";
      };
    };
}
