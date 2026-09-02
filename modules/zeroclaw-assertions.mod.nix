{
  flake.nixosModules.zeroclaw-assertions =
    { config, lib, ... }:
    let
      inherit (lib.attrsets)
        attrByPath
        attrNames
        hasAttrByPath
        mapAttrsToList
        ;
      inherit (lib.lists)
        concatMap
        elem
        imap0
        length
        optional
        ;
      inherit (lib.strings) concatStringsSep splitString;

      # ZeroClaw's `settings` is a freeform TOML blob: nothing in the module
      # system knows what a valid reference looks like, and `Config::validate()`
      # only runs once the unit is already starting on the box. Everything
      # below re-states the reference rules that validate() hard-fails on, so a
      # dangling alias is an eval error at `nixos-rebuild` / `nix flake check`
      # time instead of a crash-looping unit after deployment.
      #
      # This deliberately covers references, not fields. Unknown *keys* are
      # silently dropped by serde (the schema sets `deny_unknown_fields` in
      # only a handful of places), so a misspelt field can never be caught
      # from Nix — that is what the `zeroclaw-config` flake check is for.

      # A dotted `<type>.<alias>` reference resolving into a two-level map.
      resolves =
        ref: root:
        let
          parts = splitString "." ref;
        in
        length parts == 2 && hasAttrByPath parts root;

      checkInstance =
        instanceName: instance:
        let
          inherit (instance) settings;

          inherit (settings) agents;
          inherit (settings) channels;
          inherit (settings) cron;
          inherit (settings) heartbeat;
          models = settings.providers.models or { };
          riskProfiles = settings.risk_profiles or { };

          where = path: "services.zeroclaw.instances.${instanceName}.settings.${path}";

          known = root: concatStringsSep ", " (attrNames root);

          # Every alias declared under providers.models, flattened to the
          # dotted form a reference has to use.
          modelAliases = concatMap (family: map (alias: "${family}.${alias}") (attrNames models.${family})) (
            attrNames models
          );

          agentChecks = mapAttrsToList (
            agentName: agent:
            let
              modelProvider = agent.model_provider or null;
              riskProfile = agent.risk_profile or null;
            in
            optional (modelProvider != null) {
              assertion = resolves modelProvider models;
              message = ''
                ${where "agents.${agentName}.model_provider"} = "${modelProvider}"
                does not resolve to a configured [providers.models.<type>.<alias>]
                entry. ZeroClaw fails Config::validate() at startup on this.
                Configured aliases: ${concatStringsSep ", " modelAliases}
              '';
            }
            ++ optional (riskProfile != null) {
              assertion = elem riskProfile (attrNames riskProfiles);
              message = ''
                ${where "agents.${agentName}.risk_profile"} = "${riskProfile}"
                does not resolve to a configured [risk_profiles.<alias>] entry.
                ZeroClaw fails Config::validate() at startup on this.
                Configured profiles: ${known riskProfiles}
              '';
            }
            ++ imap0 (index: ref: {
              # Channel refs must be dotted AND land in a channel *map*.
              # `[channels] cli` is a plain bool, so "cli" and "cli.main" are
              # both dangling references — the CLI is switched on by
              # `channels.cli = true` and bound to no agent.
              assertion = resolves ref channels;
              message = ''
                ${where "agents.${agentName}.channels[${toString index}]"} = "${ref}"
                must be a dotted `<type>.<alias>` reference resolving into a
                configured channel map. ZeroClaw fails Config::validate() at
                startup on this. Note that `channels.cli` is a boolean, not a
                map, so it can never be referenced here — leave the list empty
                for an agent driven by the heartbeat, cron, or the CLI.
              '';
            }) (agent.channels or [ ])
            ++ imap0 (index: job: {
              assertion = elem job (attrNames cron);
              message = ''
                ${where "agents.${agentName}.cron_jobs[${toString index}]"} = "${job}"
                names no [cron.<alias>] entry, so the job silently never runs.
                Configured jobs: ${known cron}
              '';
            }) (agent.cron_jobs or [ ])
          ) agents;

          # A dangling fallback is only a runtime *warning* upstream — the link
          # is skipped and the agent still starts. That is precisely the
          # failure worth catching here: a typo silently removes a rung from
          # the rotation ladder and nothing ever says so.
          fallbackChecks = concatMap (
            family:
            concatMap (
              alias:
              let
                entry = models.${family}.${alias};
                self = "${family}.${alias}";
                primary = entry.model or null;
              in
              imap0 (index: ref: {
                assertion = resolves ref models && ref != self;
                message = ''
                  ${where "providers.models.${family}.${alias}.fallback[${toString index}]"} = "${ref}"
                  ${
                    if ref == self then
                      "points at its own alias, which ZeroClaw prunes as a cycle."
                    else
                      "does not resolve to a configured provider alias, so ZeroClaw drops this rung of the fallback chain at runtime without failing."
                  }
                  Configured aliases: ${concatStringsSep ", " modelAliases}
                '';
              }) (entry.fallback or [ ])
              ++ imap0 (index: model: {
                assertion = model != "" && model != primary;
                message = ''
                  ${where "providers.models.${family}.${alias}.fallback_models[${toString index}]"} = "${model}"
                  is empty or duplicates the alias's primary `model`, so
                  ZeroClaw skips it at runtime.
                '';
              }) (entry.fallback_models or [ ])
            ) (attrNames models.${family})
          ) (attrNames models);

          heartbeatChecks = optional (heartbeat.enabled or false) {
            assertion = elem (heartbeat.agent or "") (attrNames agents);
            message = ''
              ${where "heartbeat.agent"} = "${heartbeat.agent or ""}" names no
              configured [agents.<alias>] entry, so the heartbeat has nothing
              to wake. Configured agents: ${known agents}
            '';
          };

          # An agent job with no prompt (or a shell job with no command) is
          # accepted by the schema and then does nothing on every tick.
          cronChecks = mapAttrsToList (
            jobName: job:
            let
              jobType = job.job_type or "shell";
              required = if jobType == "agent" then "prompt" else "command";
            in
            {
              assertion = (job.${required} or "") != "";
              message = ''
                ${where "cron.${jobName}"} has job_type = "${jobType}" but no
                `${required}`, so every tick is a no-op. An "agent" job needs a
                `prompt`; a "shell" job needs a `command`.
              '';
            }
          ) cron;
        in
        concatMap (checks: checks) agentChecks ++ fallbackChecks ++ heartbeatChecks ++ cronChecks;
    in
    {
      # `box` blanket-imports every `flake.nixosModules` entry, so this module
      # is evaluated on hosts that never import ZeroClaw's. Reading the option
      # through attrByPath keeps it a no-op there instead of failing the whole
      # evaluation on a missing attribute.
      assertions =
        let
          instances = attrByPath [ "services" "zeroclaw" "instances" ] { } config;
        in
        concatMap (instanceName: checkInstance instanceName instances.${instanceName}) (
          attrNames instances
        );
    };
}
