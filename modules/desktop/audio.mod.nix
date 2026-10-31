{
  flake.nixosModules.desktop-audio = {
    config = {
      security.rtkit.enable = true;

      services.pipewire = {
        enable = true;
        alsa.enable = true;
        pulse.enable = true;
        wireplumber.enable = true;
      };
    };
  };
}
