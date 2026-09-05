{
  inputs,
  lib,
  self,
  ...
}:
let
  inherit (lib.attrsets)
    listToAttrs
    mapAttrsToList
    nameValuePair
    optionalAttrs
    ;
  inherit (lib.lists)
    concatLists
    imap1
    singleton
    unique
    ;
  inherit (lib.modules) mkForce;
  inherit (lib.strings) fileContents replaceStrings;

  # ADDRESSES
  # The gateway holds every vendor credential and the memory server is a
  # backend, so both stay on loopback and are reached by the agents over it.
  # The two web surfaces bind the wildcard: WAN never reaches this LXC
  # directly, only through the OPNsense VM router's WireGuard, so 0.0.0.0 here
  # is a LAN boundary rather than a public one — the same call the ZeroClaw
  # host makes for its gateway.
  gatewayPort = 4000;
  memoryPort = 49374;
  dashboardPort = 9119;
  opencodePort = 4096;

  gatewayUrl = "http://127.0.0.1:${toString gatewayPort}/v1";
  memoryUrl = "http://127.0.0.1:${toString memoryPort}/mcp";

  # MODEL GROUPS
  # The two aliases every client asks the gateway for. Bound here because
  # each one is otherwise spelled in five places — the ladder, LiteLLM's
  # fallbacks, and the three clients — and a rename that misses one is a
  # model-not-found error on the first request rather than a build failure.
  heavy = "free-heavy";
  fast = "free-fast";

  # SECRETS
  # One env file per unit rather than one shared file, so a compromise of
  # either agent — both of which run arbitrary commands as their own user by
  # design — does not hand over the vendor keys. systemd reads these as root
  # before dropping privileges, so 0400 root:root is enough and no service
  # user can open them; each unit gets only the variables it needs.
  secretsDir = "/var/lib/secrets/inference";

  envFileFor = service: "${secretsDir}/${service}.env";

  # FREE-TIER LADDER
  # Two model groups rather than one, because the two jobs have different
  # shapes. `free-heavy` runs the agent turn and needs tool calling and a real
  # context window; `free-fast` runs everything that happens *around* a turn —
  # title generation, compression, memory query rewriting, opencode's
  # small-model work — which is most of the request count and none of the
  # difficulty. Pointing both at one model is how a free tier gets exhausted
  # by bookkeeping.
  #
  # Within a group, `order` is the rung. LiteLLM only dispatches to the lowest
  # order present and treats higher ones as automatic fallbacks, so this is
  # the same best-first ladder the ZeroClaw host builds by hand — but the walk
  # down it is the router's job here, not the agent's, which is what lets
  # Hermes, opencode and ai-memory share one ladder instead of each carrying a
  # copy.
  #
  # NO rpm/tpm HERE, DELIBERATELY. LiteLLM's limits are per-minute and every
  # one of these vendors meters a daily request or token quota, so any
  # per-minute number would be invented. The ladder is driven by observed 429s
  # instead: `RateLimitErrorAllowedFails = 0` benches a deployment the moment
  # it rate-limits and the router moves to the next rung, which is the
  # behaviour a daily quota actually needs.
  #
  # Model ids are vendor-side names and they drift. These are the ones this
  # repo audited for the ZeroClaw ladder (Cerebras' public docs table, Groq's
  # rate-limit table, a keyless fetch of OpenRouter's /models endpoint), plus
  # gemini-3.6-flash/gemini-3.5-flash-lite confirmed live against the AI
  # Studio key on 2026-09-05 after gemini-2.5-flash/-lite 404'd here too
  # ("no longer available to new users") — same key as ZeroClaw, same
  # deprecation. groq/openai/gpt-oss-20b replaces llama-3.1-8b-instant the
  # same day: Groq dropped its whole Llama lineup from this key's catalog,
  # same as it once dropped Cerebras' — confirmed via a live /v1/models
  # fetch, no Llama model of any kind left. Reusing one audited set keeps
  # the two hosts from disagreeing
  # about what is live. A stale id degrades rather than breaks — LiteLLM cools that
  # deployment down on the vendor's 404 and the ladder continues — but unlike
  # the ZeroClaw host there is no drift timer auditing it here, and that gap is
  # deliberate: LiteLLM's equivalent is `background_health_checks`, which
  # spends the very quota the ladder exists to protect. Drift shows up as a
  # permanently benched rung in the journal, and `/model/info` on the gateway
  # lists what it believes it serves.
  ladder = {
    ${heavy} = [
      {
        model = "groq/openai/gpt-oss-120b";
        keyEnv = "GROQ_API_KEY";
        tools = true;
      }
      {
        model = "cerebras/gpt-oss-120b";
        keyEnv = "CEREBRAS_API_KEY";
        tools = true;
      }
      {
        model = "openrouter/z-ai/glm-5.2:free";
        keyEnv = "OPENROUTER_API_KEY";
        tools = true;
      }
      {
        model = "gemini/gemini-3.6-flash";
        keyEnv = "GEMINI_API_KEY";
        tools = true;
      }
    ];

    ${fast} = [
      {
        model = "groq/openai/gpt-oss-20b";
        keyEnv = "GROQ_API_KEY";
        tools = true;
      }
      {
        model = "gemini/gemini-3.5-flash-lite";
        keyEnv = "GEMINI_API_KEY";
        tools = true;
      }
      {
        # Left without a tool-calling claim on purpose: LiteLLM's pre-call
        # checks read `supports_function_calling`, and asserting it for a
        # model whose support is unverified would route tool requests to a
        # rung that cannot serve them. Unset means LiteLLM uses its own
        # metadata instead of ours.
        model = "cerebras/gemma-4-31b";
        keyEnv = "CEREBRAS_API_KEY";
      }
      {
        model = "openrouter/nvidia/nemotron-3-super-120b-a12b:free";
        keyEnv = "OPENROUTER_API_KEY";
        tools = true;
      }
    ];
  };

  # A deployment id LiteLLM keeps stable across restarts, so cooldown logs
  # name a rung instead of a fresh uuid.
  idOf = replaceStrings [ "/" ":" ] [ "-" "-" ];

  # Destructured strictly — no `...` — so the rung shape above is checked while
  # Nix evaluates. That matters most for `tools`: read as `rung.tools or false`
  # through a permissive pattern, a rung spelling it `tool` would have been
  # accepted, silently resolved to false, and quietly dropped
  # `supports_function_calling` from a deployment that does support it. Named
  # here, the same typo is an eval error.
  deploymentsFor =
    group: rungs:
    imap1 (
      order:
      {
        model,
        keyEnv,
        tools ? false,
      }:
      {
        model_name = group;

        litellm_params = {
          inherit model order;
          api_key = "os.environ/${keyEnv}";
          drop_params = true;

          # Truthful for a free endpoint, and it stops LiteLLM from
          # attributing the paid price of the same model id to a request that
          # cost nothing. The flip side is that a tier which quietly started
          # billing would still report zero here — the vendor's own console
          # stays the only place that says otherwise.
          input_cost_per_token = 0;
          output_cost_per_token = 0;
        };

        model_info = {
          id = "${group}-${idOf model}";
          mode = "chat";
        }
        // optionalAttrs tools {
          supports_function_calling = true;
        };
      }
    ) rungs;

  # The vendor credentials the operator has to supply, as data rather than as
  # generated shell: adding a rung above needs no change to the provisioning
  # script, and shellcheck still runs over that script at build time.
  vendorKeys =
    ladder
    |> mapAttrsToList (_group: rungs: map ({ keyEnv, ... }: keyEnv) rungs)
    |> concatLists
    |> unique;

  modules = [
    "${inputs.nixpkgs}/nixos/modules/virtualisation/proxmox-lxc.nix"
    self.nixosModules.security
    self.nixosModules.shell
    self.nixosModules.nix
    self.nixosModules.nuke-default-packages
    self.nixosModules.secrets
    self.nixosModules.hermes
    self.nixosModules.opencode
    self.nixosModules.ai-memory
  ]
  ++ singleton (
    { pkgs, ... }:
    let
      agents = inputs.llm-agents.packages.${pkgs.stdenv.hostPlatform.system};

      keysScript = pkgs.writeShellApplication {
        name = "hermes-keys";
        runtimeInputs = [
          pkgs.coreutils
          pkgs.jq
          pkgs.openssl
          pkgs.python3
          pkgs.systemd
        ];
        runtimeEnv = {
          VENDOR_KEYS = pkgs.writers.writeJSON "hermes-vendor-keys.json" vendorKeys;
          SECRETS_DIR = secretsDir;
          LITELLM_ENV = envFileFor "litellm";
          HERMES_ENV = envFileFor "hermes";
          OPENCODE_ENV = envFileFor "opencode";
          MEMORY_ENV = envFileFor "ai-memory";
        };

        text = fileContents ./hermes-keys.sh;
      };
    in
    {
      shell.default = "bash";

      environment.systemPackages = [
        pkgs.git
        agents.hermes-agent
        agents.opencode
        agents.ai-memory

        # PROVISIONING
        # Interactive, operator-run, never touched at boot. Prompts for the
        # four vendor keys and a dashboard password, mints everything else
        # itself, and writes one 0400 env file per unit.
        keysScript
      ];

      # The module owns the directory and the mode; `hermes-keys` owns the
      # content. Declared without a generator because the vendor keys have no
      # local source of truth, and every unit below carries a
      # ConditionPathExists on its own file, so before provisioning the stack
      # stays cleanly inactive instead of crash-looping.
      secrets.files = listToAttrs (
        map (service: nameValuePair "inference/${service}.env" { path = envFileFor service; }) [
          "ai-memory"
          "hermes"
          "litellm"
          "opencode"
        ]
      );

      # ----------------------------------------------------------------
      # LiteLLM — the only process holding vendor credentials
      # ----------------------------------------------------------------

      services.litellm = {
        enable = true;
        host = "127.0.0.1";
        port = gatewayPort;
        environmentFile = envFileFor "litellm";

        settings = {
          model_list = concatLists (mapAttrsToList deploymentsFor ladder);

          router_settings = {
            # Within one rung, spread across whatever deployments share it.
            # The rung ordering above is what makes this best-first; the
            # shuffle only decides between equals.
            routing_strategy = "simple-shuffle";

            # Filter on context length and known rate-limit state before
            # dispatch, so an over-long request drops to a rung that can hold
            # it instead of bouncing off the vendor first.
            enable_pre_call_checks = true;

            num_retries = 2;
            timeout = 300;

            # One failure benches a deployment for five minutes. On a paid
            # fleet this would be twitchy; on a free tier, where the usual
            # failure is a quota that will not come back for hours, retrying
            # the same vendor is the wrong instinct.
            allowed_fails = 1;
            cooldown_time = 300;

            allowed_fails_policy = {
              # A 429 is a fact about quota, not a transient. Bench on the
              # first one and walk the ladder.
              RateLimitErrorAllowedFails = 0;

              # A bad key is worth benching immediately too — it will not fix
              # itself before the next request.
              AuthenticationErrorAllowedFails = 0;
            };

            retry_policy = {
              # Never retry into a rate limit or a rejected request; move on.
              RateLimitErrorRetries = 0;
              AuthenticationErrorRetries = 0;
              BadRequestErrorRetries = 0;
              ContentPolicyViolationErrorRetries = 0;

              TimeoutErrorRetries = 1;
              InternalServerErrorRetries = 1;
            };

            # A slower, smaller answer beats no answer once every heavy rung
            # is spent. The reverse is deliberately absent: promoting routine
            # bookkeeping to the heavy group is how the heavy group runs out.
            fallbacks = singleton { ${heavy} = singleton fast; };

            # The one case where the fast group should reach up: a request too
            # long for a small model's window is not a quota problem and will
            # fail identically on every fast rung.
            context_window_fallbacks = singleton { ${fast} = singleton heavy; };
          };

          litellm_settings = {
            # In front of four vendors with four different parameter sets,
            # this is what keeps one request shape working across all of them.
            drop_params = true;

            json_logs = true;

            # The journal is not a transcript store. Without this, every
            # prompt and completion the agents exchange lands in it.
            turn_off_message_logging = true;
            redact_user_api_key_info = true;

            request_timeout = 300;

            # Retries belong to the router, which knows about rungs and
            # cooldowns. Leaving the library layer to retry as well multiplies
            # attempts against a vendor that has already said no.
            num_retries = 0;
          };

          general_settings = {
            master_key = "os.environ/LITELLM_MASTER_KEY";

            # No database on this host, which is what makes both of these
            # necessary rather than merely tidy.
            store_model_in_db = false;
            disable_spend_logs = true;

            # Each probe is a real request against a daily quota, and there
            # are eight deployments. The agents discover a dead rung through
            # the cooldown path instead, at no extra cost.
            background_health_checks = false;

            ui_access_mode = "admin_only";
            max_request_size_mb = 32;
          };
        };
      };

      # ----------------------------------------------------------------
      # ai-memory — one MCP memory server, shared by both agents
      # ----------------------------------------------------------------

      services.ai-memory = {
        enable = true;
        package = agents.ai-memory;
        environmentFile = envFileFor "ai-memory";

        listen = {
          host = "127.0.0.1";
          port = memoryPort;
        };

        # The wiki view of what the agents have written, on loopback. It is a
        # read surface for a store the agents can already rewrite through MCP,
        # so it earns no LAN exposure of its own.
        web.enable = true;

        settings = {
          log_level = "info";

          # Consolidation runs through the same ladder as everything else, on
          # the cheap group.
          llm_provider = "openai-compat";
          llm_model = fast;
          llm_base_url = gatewayUrl;
          llm_timeout_secs = 300;

          # Several free endpoints reject `response_format=json_schema`
          # outright. ai-memory's prose-instruction path works on all of them,
          # and it already extracts the first balanced object.
          llm_compat_strict = false;

          # One model call per session end, on top of the heuristic page that
          # is written regardless. Left off: the deterministic page is what the
          # agents actually read back, and the LLM pass still happens on
          # PreCompact and on an explicit consolidate.
          consolidate_on_session_end = false;

          # Keyword-only recall, which is what leaving `embedding_provider`
          # unset gets in this version: an embedder is only constructed when
          # one is named. An embedding provider is the one part of a memory
          # layer that bills per write rather than per query, which is exactly
          # wrong on a deployment whose premise is free inference.
          #
          # Not `embedding_provider = "none"`. That spelling opts out in
          # ai-memory 2.x, where the default flipped to in-process `local`
          # embeddings — but the pinned 1.38.0 matches the provider name
          # against openai/voyage/google/gemini/openai-compat and errors on
          # anything else, so naming it would stop the server starting.

          # opencode is a generic MCP client and never sends the flavour
          # marker that would trigger this automatically; without it, tools
          # whose schema has a root `anyOf` are rejected by strict upstreams.
          # Runtime validation is unaffected.
          strip_root_combinators = true;

          # Plain HTTP on loopback: a Secure cookie would be dropped by the
          # browser and web login would never complete.
          auth.secure_cookie = false;

          # Two agents share this server, so the "current project" pointer has
          # to be keyed per actor or they overwrite each other's scope.
          auto_scope.mode = "per_actor";

          maintenance.enabled = true;
        };
      };

      # ----------------------------------------------------------------
      # Hermes — the agent and its web dashboard
      # ----------------------------------------------------------------

      services.hermes = {
        enable = true;
        package = agents.hermes-agent;
        environmentFile = envFileFor "hermes";

        dashboard = {
          host = "0.0.0.0";
          port = dashboardPort;
          openFirewall = true;
        };

        settings = {
          # `custom` is Hermes' name for a plain OpenAI-compatible endpoint.
          # `${...}` is expanded from the process environment when the managed
          # file is merged, so the credential comes from the unit's env file
          # and not from the store.
          model = {
            provider = "custom";
            base_url = gatewayUrl;
            api_key = "\${LITELLM_MASTER_KEY}";
            default = heavy;
          };

          # Everything that fires around a turn rather than as one. These are
          # the calls that outnumber real turns several to one, and sending
          # them to the heavy group is how a day's quota disappears into title
          # generation.
          auxiliary =
            let
              # Named for what it is rather than for the group, so it cannot
              # shadow `fast` — which is the group name this very attrset
              # needs to reference.
              onFastGroup = {
                provider = "custom";
                base_url = gatewayUrl;
                api_key = "\${LITELLM_MASTER_KEY}";
                model = fast;
              };
            in
            {
              approval = onFastGroup;
              compression = onFastGroup;
              memory_query_rewrite = onFastGroup;
              title_generation = onFastGroup;
            };

          mcp_servers.memory = {
            url = memoryUrl;
            headers.Authorization = "Bearer \${AI_MEMORY_AUTH_TOKEN}";

            # ai-memory expires idle MCP sessions; ping inside that window so
            # an idle tool call does not pay a reconnect.
            keepalive_interval = 60;
          };

          # `smart` grades each call and stops only for the risky ones. Every
          # non-interactive path denies by default: a cron job or an
          # unattended platform has nobody to answer a prompt, so the
          # alternative to denying is blocking for the full approval timeout
          # with no listener.
          approvals = {
            mode = "smart";
            cron_mode = "deny";
            single_query_mode = "deny";
            unattended_mode = "deny";
          };

          # The schedule is the host's, not the agent's. Jobs still run; the
          # agent just cannot add ones a rebuild would not know about.
          cron.allow_agent_scheduling = false;

          security = {
            redact_secrets = true;
            protected_instruction_files = true;

            # The store is read-only, so a lazy install can only fail and then
            # silently disable whatever it was for.
            allow_lazy_installs = false;
          };

          # The point of this box is inference that costs nothing, which
          # includes search: with no paid search credential configured, these
          # are what keep the web tool working instead of dead.
          web = {
            keyless_fallback = true;
            keyless_rescue = true;
            cache_enabled = true;
          };

          memory = {
            memory_enabled = true;
            user_profile_enabled = true;
          };

          sessions = {
            auto_prune = true;
            retention_days = 60;
            auto_archive = true;
            auto_archive_days = 7;
          };

          curator.enabled = true;

          database.journal_mode = "wal";

          logging.level = "INFO";
        };
      };

      # ----------------------------------------------------------------
      # opencode — the coding agent, same ladder, same memory
      # ----------------------------------------------------------------

      services.opencode = {
        enable = true;
        package = agents.opencode;
        environmentFile = envFileFor "opencode";

        listen = {
          host = "0.0.0.0";
          port = opencodePort;
          openFirewall = true;
        };

        settings = {
          # Not decorative: without it opencode rewrites the config file to
          # add the key on first load. The write fails harmlessly against a
          # store symlink, but it fails on every start.
          "$schema" = "https://opencode.ai/config.json";

          autoupdate = false;
          share = "disabled";
          logLevel = "INFO";

          # The gateway is the only way out of this box, so nothing else is
          # allowed to load. Without this, a stray provider credential
          # anywhere in the environment silently adds a direct route that
          # bypasses the ladder, the cooldowns and the spend accounting.
          enabled_providers = singleton "litellm";

          model = "litellm/${heavy}";
          small_model = "litellm/${fast}";

          provider.litellm = {
            name = "LiteLLM (free-tier ladder)";

            # opencode fetches this AI SDK package at runtime into its own
            # cache rather than having it in the closure, which is why the
            # unit needs both network access and a writable state directory.
            npm = "@ai-sdk/openai-compatible";

            options = {
              baseURL = gatewayUrl;
              apiKey = "{env:LITELLM_MASTER_KEY}";

              # Milliseconds, unlike everything else in this file. A free rung
              # can sit queued for a long time before the first token arrives,
              # and the default would abandon the request while it is still
              # coming.
              chunkTimeout = 300000;
            };

            # Both groups' limits are the smallest window across their rungs,
            # not the largest: the request has to fit whichever rung the
            # router lands on, and a figure taken from the roomiest vendor
            # would let opencode build a context the next rung down rejects.
            models = {
              ${heavy} = {
                name = "Free tier — heavy";
                tool_call = true;
                reasoning = true;
                cost = {
                  input = 0;
                  output = 0;
                };
                limit = {
                  context = 131072;
                  output = 32768;
                };
              };

              ${fast} = {
                name = "Free tier — fast";
                tool_call = true;
                cost = {
                  input = 0;
                  output = 0;
                };
                limit = {
                  context = 131072;
                  output = 8192;
                };
              };
            };
          };

          mcp.memory = {
            type = "remote";
            url = memoryUrl;
            enabled = true;
            headers.Authorization = "Bearer {env:AI_MEMORY_AUTH_TOKEN}";

            # Nothing on loopback is going to complete an OAuth discovery
            # round trip; turning it off removes a failing request from every
            # startup.
            oauth = false;
          };

          # Reachable from the LAN, so the destructive tools ask first and the
          # escape hatch out of the workspace is closed.
          permission = {
            bash = "ask";
            edit = "ask";
            external_directory = "deny";
            webfetch = "allow";
            websearch = "allow";
          };

          # Planning should be able to read everything and change nothing.
          agent.plan.permission = {
            bash = "deny";
            edit = "deny";
          };
        };
      };

      # ----------------------------------------------------------------
      # Resource caps and ordering
      # ----------------------------------------------------------------

      # Upstream's litellm unit uses DynamicUser with PrivateUsers, which needs
      # a nested user namespace. An unprivileged Proxmox container only has one
      # when nesting is enabled on the container, and the failure mode is a
      # unit that never starts — so it is turned off here rather than left as a
      # property of the hypervisor's configuration.
      systemd.services.litellm = {
        unitConfig.ConditionPathExists = envFileFor "litellm";
        after = singleton "secrets-bootstrap.service";
        serviceConfig = {
          PrivateUsers = mkForce false;
          MemoryMax = "1536M";
          MemoryHigh = "1280M";
          CPUQuota = "150%";
        };
      };

      systemd.services.ai-memory = {
        unitConfig.ConditionPathExists = envFileFor "ai-memory";
        after = singleton "secrets-bootstrap.service";
        serviceConfig = {
          MemoryMax = "1024M";
          MemoryHigh = "768M";
          CPUQuota = "100%";
        };
      };

      # Both agents are ordered after the gateway and the memory server, but
      # not bound to them: a dependency would make a gateway restart tear down
      # live sessions, and both agents already treat their backends as things
      # that can be unreachable for a while.
      systemd.services.hermes-dashboard = {
        unitConfig.ConditionPathExists = envFileFor "hermes";
        after = [
          "ai-memory.service"
          "litellm.service"
          "secrets-bootstrap.service"
        ];
        serviceConfig = {
          MemoryMax = "3G";
          MemoryHigh = "2560M";
          CPUQuota = "200%";
          TasksMax = 1024;
        };
      };

      systemd.services.opencode = {
        unitConfig.ConditionPathExists = envFileFor "opencode";
        after = [
          "ai-memory.service"
          "litellm.service"
          "secrets-bootstrap.service"
        ];
        serviceConfig = {
          MemoryMax = "2G";
          MemoryHigh = "1536M";
          CPUQuota = "200%";
          TasksMax = 1024;
        };
      };

      # ----------------------------------------------------------------
      # Container basics
      # ----------------------------------------------------------------

      services.openssh.enable = false;
      services.getty.autologinUser = "root";

      xdg.sounds.enable = false;
      xdg.mime.enable = false;
      xdg.icons.enable = false;
      fonts.fontconfig.enable = false;

      nixpkgs.hostPlatform = "x86_64-linux";
      system.stateVersion = "25.11";
    }
  );
in
{
  flake.nixosConfigurations.hermes-server-lxc = inputs.nixpkgs.lib.nixosSystem {
    inherit modules;
  };

  flake.packages.x86_64-linux.hermes-server-lxc =
    self.nixosConfigurations.hermes-server-lxc.config.system.build.tarball;
}
