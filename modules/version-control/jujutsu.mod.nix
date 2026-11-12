{
  flake.homeModules.jujutsu =
    { lib, pkgs, ... }:
    let
      inherit (lib.lists) singleton;
      inherit (lib.meta) getExe;
    in
    {
      packages = [
        pkgs.jjui
        pkgs.jujutsu
        pkgs.mergiraf
      ];

      xdg.config.files."jj/config.toml".generator = pkgs.writers.writeTOML "jj-config.toml";
      xdg.config.files."jj/config.toml".value = {
        user.name = "Chuccle";
        user.email = "chuccle@example.com";

        aliases.".." = [
          "edit"
          "@-"
        ];
        aliases.",," = [
          "edit"
          "@+"
        ];

        aliases.f = [
          "git"
          "fetch"
        ];

        aliases.p = [
          "git"
          "push"
        ];

        aliases.cl = [
          "git"
          "clone"
        ];

        aliases.i = [
          "git"
          "init"
        ];

        aliases.a = singleton "abandon";

        aliases.c = singleton "commit";
        aliases.ci = [
          "commit"
          "--interactive"
        ];

        aliases.d = singleton "diff";

        aliases.e = singleton "edit";

        aliases.l = singleton "log";
        aliases.la = [
          "log"
          "--revisions"
          "::"
        ];

        aliases.r = singleton "rebase";

        aliases.res = singleton "resolve";

        aliases.resa = singleton "resolve-ast";
        aliases.resolve-ast = [
          "resolve"
          "--tool"
          "${getExe pkgs.mergiraf}"
        ];

        aliases.s = singleton "squash";
        aliases.si = [
          "squash"
          "--interactive"
        ];

        aliases.sh = singleton "show";

        aliases.u = singleton "undo";

        revsets.bookmark-advance-to = /* jj */ ''
          heads(::@ & ~description(exact:"") & (~empty() | merges()))
        '';

        revsets.log = /* jj */ ''
          present(@) | present(trunk()) | ancestors(remote_bookmarks().. | @.., 8)
        '';

        ui.diff-editor = ":builtin";
        ui.diff-formatter = [
          (getExe pkgs.difftastic)
          "--color"
          "always"
          "$left"
          "$right"
        ];
        ui.pager = [
          (getExe pkgs.bash)
          "-c"
          "exec \${PAGER:-less}"
        ];

        ui.conflict-marker-style = "snapshot";
        ui.graph.style = "curved";

        templates.draft_commit_description = /* jj */ ''
          concat(
            coalesce(description, "\n"),
            surround(
              "\nJJ: This commit contains the following changes:\n", "",
              indent("JJ:     ", diff.stat(72)),
            ),
            "\nJJ: ignore-rest\n",
            diff.git(),
          )
        '';

        templates.git_push_bookmark = /* jj */ ''
          "chuccle/change-" ++ change_id.short()
        '';

        remotes."*" = {
          push-new-bookmarks = true;
        };

        git.fetch = [
          "origin"
          "upstream"
          "rad"
        ];
        git.push = "origin";
      };
    };
}
