{
  perSystem =
    { config, ... }:
    {
      formatter = config.dev.treefmt.config.build.wrapper;
    };
}
