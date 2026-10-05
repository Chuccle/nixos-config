{ self, ... }:
{
  flake.nixosModules.boot-desktop =
    { lib, ... }:
    let
      inherit (lib.lists) singleton;
    in
    {
      imports = singleton self.nixosModules.boot;

      config = {
        boot.loader.systemd-boot.consoleMode = "keep";
        boot.loader.timeout = 0;

        boot.consoleLogLevel = 3;
        boot.initrd.verbose = false;
        boot.kernelParams = singleton "quiet";

        boot.plymouth = {
          enable = true;
          theme = "spinner";
        };
      };
    };
}
