{ inputs, lib, ... }:
let
  inherit (lib.attrsets) attrNames mapAttrsToList;
  inherit (lib.fixedPoints) fix;
  inherit (lib.lists)
    elem
    filter
    singleton
    ;
  inherit (lib.trivial) importJSON;
  inherit (lib.strings) hasInfix;

  extensions = {
    clearurls.id = "lckanjgmijmafbedllaakclkaicjfmnk";
    dark-reader.id = "eimadpbcbfnmbkopoojfekhnkhdbieeh";
    dearrow.id = "enamippconapkdmgfgjchkhakpfinmaj";
    floccus.id = "fnaicdffflnofjppbagibeoednhnbjhg";
    i-still-dont-care-about-cookies.id = "edibdbjcniadpccecjdfdjjppcpchdlm";
    kagi.id = "cdglnehniifkbagbbombnjghhcihifij";
    old-reddit-redirect.id = "dneaehbmnbhcippjikoajpoabadpodje";
    refined-github.id = "hlepfoohegkhhmjieoechaddaejaokhf";
    sponsorblock.id = "mnjggcdmjocbbbhaepdhchncahnbgone";
    stylus.id = "clngdbkpkpeebahjckkjfobafhncgmne";
    ublock-origin = fix (self: {
      id = "cjpalhdlnbpafiamejdnhcphjbkeiagm";

      filters.internal = attrNames <| importJSON "${inputs.ublock}/assets/assets.json";

      filters.wanted = [
        "ublock-filters"
        "ublock-badware"
        "ublock-privacy"
        "ublock-unbreak"
        "easylist"
        "easyprivacy"
        "urlhaus-1"
        "plowe-0"

        "https://raw.githubusercontent.com/DandelionSprout/adfilt/refs/heads/master/ClearURLs%20for%20uBo/clear_urls_uboified.txt"
        "https://raw.githubusercontent.com/yokoffing/filterlists/refs/heads/main/privacy_essentials.txt"
        "https://raw.githubusercontent.com/DandelionSprout/adfilt/refs/heads/master/LegitimateURLShortener.txt"
        "https://raw.githubusercontent.com/yokoffing/filterlists/refs/heads/main/annoyance_list.txt"
        "https://raw.githubusercontent.com/DandelionSprout/adfilt/refs/heads/master/BrowseWebsitesWithoutLoggingIn.txt"
      ];

      filters.warnings =
        self.filters.wanted
        # Not external and not in internal list.
        |> filter (name: !(hasInfix "://" name || elem name self.filters.internal))
        |> map (invalid: "helium: unknown ublock filter list: ${invalid}");
    });
    vimium-c.id = "hfjbmagddngcpeloejdejnfgbamkjaeg";
    violentmonkey.id = "jinjaccalgkegednnccohejagnlnfdag";
    web-archives.id = "hkligngkgcpcolhcnkgccglchdafcnao";
  };

  policy = {
    # EXTENSIONS
    ExtensionInstallForcelist =
      extensions |> mapAttrsToList (_name: { id, ... }: "${id};https://services.helium.imput.net/ext");
    ExtensionInstallAllowlist = extensions |> mapAttrsToList (_name: { id, ... }: id);
    ExtensionInstallSources = singleton "https://services.helium.imput.net/*";

    # UBLOCK ORIGIN
    "3rdparty".extensions.${extensions.ublock-origin.id}.toOverwrite.filterLists =
      extensions.ublock-origin.filters.wanted;

    # # Setting the policy to False stops Chrome from ever checking if
    # # it's the default and turns user controls off for this option.
    # DefaultBrowserSettingEnabled = true;

    # SEARCH
    DefaultSearchProviderEnabled = true;
    DefaultSearchProviderName = "Kagi";
    DefaultSearchProviderSearchURL = "https://kagi.com/search?q={searchTerms}";
    DefaultSearchProviderSuggestURL = "https://kagi.com/api/autosuggest?q={searchTerms}";
    SearchSuggestEnabled = true;
  };
in
{
  flake.nixosModules.helium =
    { lib, ... }:
    let
      inherit (lib.strings) toJSON;
    in
    {
      inherit (extensions.ublock-origin.filters) warnings;

      environment.etc."chromium/policies/managed/policies.json".text = toJSON policy;
    };

  flake.homeModules.helium =
    {
      lib,
      osConfig,
      ...
    }:
    let
      inherit (lib.lists) singleton;
      inherit (lib.trivial) const flip;
      inherit (lib.attrsets) genAttrs;
    in
    {
      inherit (extensions.ublock-origin.filters) warnings;

      environment.sessionVariables.BROWSER = "helium";

      xdg.mime-apps.default-applications = flip genAttrs (const "helium.desktop") [
        "application/pdf"
        "application/rdf+xml"
        "application/rss+xml"
        "application/xhtml+xml"
        "application/xhtml_xml"
        "application/xml"
        "image/gif"
        "image/jpeg"
        "image/png"
        "image/webp"
        "text/html"
        "text/xml"
        "x-scheme-handler/http"
        "x-scheme-handler/https"
      ];

      packages = singleton inputs.helium.packages.${osConfig.nixpkgs.hostPlatform.system}.default;
    };
}
