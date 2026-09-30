{ inputs, self, ... }:
{
  perSystem =
    {
      lib,
      pkgs,
      system,
      ...
    }:
    let
      inherit (lib.attrsets)
        attrNames
        filterAttrs
        mapAttrs'
        nameValuePair
        ;
      inherit (lib.lists) singleton;
      inherit (lib.strings) concatMapStringsSep;
      treefmt = inputs.treefmt-nix.lib.evalModule pkgs (_: {
        projectRootFile = "flake.nix";
        programs = {
          nixfmt.enable = true;
          deadnix.enable = true;
          black.enable = true;
          prettier = {
            enable = true;
            package = pkgs.prettier;
            includes = [
              "*.yml"
              "*.yaml"
              "*.json"
              "*.md"
            ];
          };
          statix.enable = true;
        };
      });

      hostChecks =
        self.nixosConfigurations
        |> filterAttrs (_name: cfg: cfg.config.nixpkgs.hostPlatform.system == system)
        |> mapAttrs' (name: cfg: nameValuePair "host-${name}" cfg.config.system.build.toplevel);

      ghosttyChecks =
        self.nixosConfigurations
        |> filterAttrs (
          name: cfg:
          (name == "iso-tahoe" || name == "iso-win95") && cfg.config.nixpkgs.hostPlatform.system == system
        )
        |> mapAttrs' (
          name: cfg:
          let
            home = cfg.config.home.users.nixos;
            files = home.xdg.config.files;
          in
          nameValuePair "ghostty-${name}"
          <|
            pkgs.runCommand "ghostty-${name}-check"
              {
                nativeBuildInputs = singleton home.programs.ghostty.package;
              }
              /* bash */ ''
                export HOME="$TMPDIR/home"
                export XDG_CONFIG_HOME="$HOME/.config"
                install -Dm0644 ${files."ghostty/config".source} "$XDG_CONFIG_HOME/ghostty/config"
                ${concatMapStringsSep "\n" (theme: ''
                  install -Dm0644 ${files."ghostty/themes/${theme}".source} "$XDG_CONFIG_HOME/ghostty/themes/${theme}"
                '') (attrNames home.programs.ghostty.themes)}
                ${concatMapStringsSep "\n" (theme: ''
                  ghostty +validate-config --config-file=${
                    (pkgs.formats.keyValue { }).generate "ghostty-${theme}-validation" { inherit theme; }
                  }
                '') (attrNames home.programs.ghostty.themes)}
                touch $out
              ''
        );
    in
    {
      formatter = treefmt.config.build.wrapper;
      devShells.default = pkgs.mkShell {
        packages = [
          treefmt.config.build.wrapper
          pkgs.deadnix
          pkgs.direnv
          pkgs.nil
          pkgs.nix-direnv
          pkgs.nixfmt
          pkgs.statix
        ];
      };
      checks = {
        formatting = treefmt.config.build.check self;
        deadnix = pkgs.callPackage (
          { deadnix, stdenvNoCC }:
          stdenvNoCC.mkDerivation {
            name = "deadnix-check";
            src = self;
            nativeBuildInputs = singleton deadnix;
            buildPhase = "deadnix --fail .";
            installPhase = "touch $out";
          }
        ) { };
        statix = pkgs.callPackage (
          { statix, stdenvNoCC }:
          stdenvNoCC.mkDerivation {
            name = "statix-check";
            src = self;
            nativeBuildInputs = singleton statix;
            buildPhase = "statix check .";
            installPhase = "touch $out";
          }
        ) { };
        win95-window-control =
          pkgs.runCommand "win95-window-control-check"
            {
              nativeBuildInputs = [
                pkgs.bash
                pkgs.coreutils
                pkgs.jq
                pkgs.util-linux
              ];
            }
            /* bash */ ''
              bash ${../shells/test-win95-window-action.sh} ${../shells/win95-window-action.sh}
              touch $out
            '';
      }
      // hostChecks
      // ghosttyChecks;
    };
}
