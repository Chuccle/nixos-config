{
  flake.homeModules.packages-media =
    { pkgs, ... }:
    {
      home.packages = [
        pkgs.yt-dlp
      ];
    };

  flake.homeModules.packages-shell-utils =
    { pkgs, ... }:
    {
      home.packages = [
        pkgs.asciinema
        pkgs.fastfetch
        pkgs.fd
        pkgs.jc
        pkgs.moreutils
        pkgs.openssl
        pkgs.p7zip
        pkgs.rclone
        pkgs.sd
        pkgs.timg
        pkgs.tokei
        pkgs.uutils-coreutils-noprefix
        pkgs.yazi
        pkgs.git
        pkgs.ripgrep
        pkgs.bat
        pkgs.eza
        pkgs.helix
      ];
    };

  flake.homeModules.packages-wisdom =
    { pkgs, ... }:
    {
      home.packages = [
        pkgs.cowsay
        (pkgs.fortune.override { withOffensive = true; })
      ];
    };

  flake.homeModules.packages-dev-tools-cc =
    { pkgs, ... }:
    {
      home.packages = [
        pkgs.clang
        pkgs.clang-tools
        pkgs.lld
      ];
    };

  flake.homeModules.packages-dev-tools-go =
    { pkgs, ... }:
    {
      home.packages = [
        pkgs.go
      ];
    };

  flake.homeModules.packages-dev-tools-rust =
    { pkgs, ... }:
    {
      home.packages = [
        pkgs.cargo-deny
        pkgs.cargo-expand
        pkgs.cargo-fuzz
        pkgs.cargo-nextest

        pkgs.evcxr

        pkgs.taplo

        pkgs.cargo
        pkgs.clippy
        pkgs.rust-analyzer
        pkgs.rustc
        pkgs.rustfmt
      ];
    };

  flake.homeModules.packages-dev-tools-python =
    { pkgs, ... }:
    let
      python = pkgs.python3;
    in
    {
      home.sessionVariables = {
        UV_PYTHON_PREFERENCE = "system";
        UV_PYTHON = "${python}";
      };

      home.packages = [
        python
        pkgs.uv
      ];
    };

  flake.nixosModules.packages-debugging-gui =
    { self, ... }:
    {
      environment.systemPackages = [
        self.packages.x86_64-linux.ida-pro
      ];

      allowedUnfreePackageNames = [ "ida-pro" ];
    };

  flake.nixosModules.packages-debugging =
    { pkgs, ... }:
    {
      environment.systemPackages = [
        pkgs.strace
        pkgs.usbutils
      ];
    };

  flake.homeModules.packages-debugging =
    { pkgs, ... }:
    {
      home.packages = [
        pkgs.hyperfine
        pkgs.typos
      ];
    };
}
