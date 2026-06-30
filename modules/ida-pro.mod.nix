{
  flake.homeModules.ida-pro =
    { config, lib, ... }:
    let
      inherit (lib.lists) singleton;
      inherit (lib.modules) mkIf;
      inherit (lib.options) mkOption;
      inherit (lib.types) nullOr package;
    in
    {
      options.ida-pro = {
        package = mkOption {
          type = nullOr package;
          default = null;
          description = "The IDA Pro package to use.";
        };
      };

      config = mkIf (config.ida-pro.package != null) {
        packages = singleton config.ida-pro.package;
      };
    };
}
