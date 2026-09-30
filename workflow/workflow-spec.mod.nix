{ lib, ... }:
let
  inherit (lib.asserts) assertMsg;
  inherit (lib.lists)
    all
    any
    elem
    map
    unique
    ;
  inherit (lib.modules) evalModules;
  inherit (lib.types)
    attrsOf
    bool
    either
    enum
    float
    int
    listOf
    str
    submodule
    ;

  config = lib.importJSON ./config.json;
  criteria = lib.importJSON ./criteria.json;
  references = lib.importJSON ./references.json;
  reviewSchema = lib.importJSON ./visual-review.schema.json;
  referenceIds = map ({ id, ... }: id) references;
  validatedReferences =
    assert assertMsg (unique referenceIds == referenceIds) "Inspection reference IDs must be unique";
    assert assertMsg (all (
      id: elem id referenceIds
    ) criteria.references) "Every frozen criterion reference must exist";
    assert assertMsg (all
      (
        targetEdition: any ({ edition, kind, ... }: edition == targetEdition && kind == "image") references
      )
      [
        "tahoe"
        "win95"
      ]
    ) "Each edition needs an image reference";
    references;
  number = either int float;
  validatedConfig =
    assert config.maxRepairs >= 0 && config.maxRepairs <= 3;
    assert config.maxHours > 0 && config.maxHours <= 6;
    assert config.confirmBoots >= 3;
    assert config.settleSeconds >= 60;
    assert config.sampleSeconds >= 120;
    assert config.metricsTimeoutSeconds >= config.settleSeconds + config.sampleSeconds + 60;
    config;

  evaluated = evalModules {
    modules = [
      {
        options = {
          config = lib.mkOption {
            type = submodule {
              options = {
                artifactRoot = lib.mkOption { type = str; };
                vmRoot = lib.mkOption { type = str; };
                composeProject = lib.mkOption { type = str; };
                container = lib.mkOption { type = str; };
                nixStateDir = lib.mkOption { type = str; };
                vmrun = lib.mkOption { type = str; };
                vmwareLeaseFiles = lib.mkOption { type = listOf str; };
                jj = lib.mkOption { type = str; };
                candidateRoot = lib.mkOption { type = str; };
                baselineRevision = lib.mkOption { type = str; };
                maxRepairs = lib.mkOption { type = int; };
                maxHours = lib.mkOption { type = int; };
                buildTimeoutMinutes = lib.mkOption { type = int; };
                bootTimeoutSeconds = lib.mkOption { type = int; };
                metricsTimeoutSeconds = lib.mkOption { type = int; };
                settleSeconds = lib.mkOption { type = int; };
                sampleSeconds = lib.mkOption { type = int; };
                confirmBoots = lib.mkOption { type = int; };
                ramLimitGiB = lib.mkOption { type = number; };
                cpuLimitPercent = lib.mkOption { type = number; };
                readyLimitSeconds = lib.mkOption { type = int; };
                regressionPercent = lib.mkOption { type = number; };
                cpuTolerancePoints = lib.mkOption { type = number; };
                resolutions = lib.mkOption { type = listOf str; };
              };
            };
          };
          criteria = lib.mkOption {
            type = submodule {
              options = {
                common = lib.mkOption { type = listOf str; };
                functional = lib.mkOption {
                  type = submodule {
                    options = {
                      common = lib.mkOption { type = listOf str; };
                      tahoe = lib.mkOption { type = listOf str; };
                      win95 = lib.mkOption { type = listOf str; };
                    };
                  };
                };
                limitations = lib.mkOption { type = listOf str; };
                references = lib.mkOption { type = listOf str; };
                tahoe = lib.mkOption { type = listOf str; };
                win95 = lib.mkOption { type = listOf str; };
              };
            };
          };
          references = lib.mkOption {
            type = listOf (submodule {
              options = {
                id = lib.mkOption { type = str; };
                edition = lib.mkOption {
                  type = enum [
                    "tahoe"
                    "win95"
                  ];
                };
                kind = lib.mkOption {
                  type = enum [
                    "document"
                    "image"
                  ];
                };
                official = lib.mkOption { type = bool; };
                url = lib.mkOption { type = str; };
                sourcePage = lib.mkOption {
                  type = str;
                  default = "";
                };
                focus = lib.mkOption { type = str; };
              };
            });
          };
          reviewSchema = lib.mkOption { type = attrsOf lib.types.anything; };
        };

        config = {
          inherit
            criteria
            reviewSchema
            ;
          config = validatedConfig;
          references = validatedReferences;
        };
      }
    ];
  };
in
{
  perSystem =
    { config, pkgs, ... }:
    let
      json = pkgs.formats.json { };
      spec = evaluated.config;
    in
    {
      packages.desktop-inspection-spec = pkgs.linkFarm "desktop-inspection-spec" [
        {
          name = "config.json";
          path = json.generate "desktop-inspection-config.json" spec.config;
        }
        {
          name = "criteria.json";
          path = json.generate "desktop-inspection-criteria.json" spec.criteria;
        }
        {
          name = "references.json";
          path = json.generate "desktop-inspection-references.json" spec.references;
        }
        {
          name = "visual-review.schema.json";
          path = json.generate "desktop-inspection-review-schema.json" spec.reviewSchema;
        }
      ];

      checks.desktop-inspection-spec = config.packages.desktop-inspection-spec;
    };
}
