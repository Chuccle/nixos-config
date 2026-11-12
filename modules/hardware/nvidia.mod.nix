{ self, ... }:
{
  flake.nixosModules.nvidia =
    { lib, ... }:
    let
      inherit (lib.lists) singleton;
    in
    {
      imports = singleton self.nixosModules.unfree;

      config = {
        allowedUnfreePackageNames = [
          "nvidia-x11"
          "nvidia-settings"
        ];

        boot.initrd.kernelModules = [
          "nvidia"
          "nvidia_modeset"
          "nvidia_drm"
        ];

        hardware.graphics.enable = true;

        hardware.nvidia = {
          open = true;
          modesetting.enable = true;
          powerManagement.enable = true;
        };

        services.xserver.videoDrivers = singleton "nvidia";
      };
    };
}
