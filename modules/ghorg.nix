{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.services.ghorg;
  yaml = pkgs.formats.yaml { };
  hasInlineConfig =
    job:
    job.rawSettings != { }
    || builtins.any (value: value != null) [
      job.settings.scmType
      job.settings.hostname
      job.settings.baseUrl
      job.settings.cloneProtocol
      job.settings.concurrency
      job.settings.preserveDir
      job.settings.skipArchived
      job.settings.skipForks
      job.settings.includeSubgroups
      job.settings.branch
      job.settings.cloneToPath
    ];

  renderJobSettings =
    job:
    let
      typedSettings =
        lib.optionalAttrs (job.settings.scmType != null) { scm_type = job.settings.scmType; }
        // lib.optionalAttrs (job.settings.hostname != null) { hostname = job.settings.hostname; }
        // lib.optionalAttrs (job.settings.baseUrl != null) { base_url = job.settings.baseUrl; }
        // lib.optionalAttrs (job.settings.cloneProtocol != null) {
          clone_protocol = job.settings.cloneProtocol;
        }
        // lib.optionalAttrs (job.settings.concurrency != null) { concurrency = job.settings.concurrency; }
        // lib.optionalAttrs (job.settings.preserveDir != null) { preserve_dir = job.settings.preserveDir; }
        // lib.optionalAttrs (job.settings.skipArchived != null) {
          skip_archived = job.settings.skipArchived;
        }
        // lib.optionalAttrs (job.settings.skipForks != null) { skip_forks = job.settings.skipForks; }
        // lib.optionalAttrs (job.settings.includeSubgroups != null) {
          include_subgroups = job.settings.includeSubgroups;
        }
        // lib.optionalAttrs (job.settings.branch != null) { branch = job.settings.branch; }
        // {
          absolute_path_to_clone_to =
            if job.settings.cloneToPath != null then job.settings.cloneToPath else cfg.dataDir;
        };
    in
    typedSettings // job.rawSettings;

  jobConfigFile =
    name: job:
    if job.configFile != null then
      job.configFile
    else
      yaml.generate "ghorg-${name}.yaml" (renderJobSettings job);

  jobCommand =
    name: job:
    let
      commandArgs =
        job.args
        ++ [
          "--config"
          (jobConfigFile name job)
        ]
        ++ job.extraArgs;
      commandString = lib.escapeShellArgs ([ (lib.getExe cfg.package) ] ++ commandArgs);
      sourceEnv = lib.optionalString (job.environmentFile != null) ''
        set -a
        . ${lib.escapeShellArg job.environmentFile}
        set +a
      '';
    in
    pkgs.writeShellScript "ghorg-job-${name}" ''
      set -eu
      export HOME=${lib.escapeShellArg cfg.dataDir}
      ${sourceEnv}
      exec ${commandString}
    '';

  recloneConfig = yaml.generate "ghorg-reclone.yaml" (
    lib.mapAttrs (
      name: job:
      {
        cmd = toString (jobCommand name job);
      }
      // lib.optionalAttrs (job.description != null) { description = job.description; }
      // lib.optionalAttrs (job.postExecScript != null) {
        post_exec_script = toString job.postExecScript;
      }
    ) cfg.jobs
  );
in
{
  options.services.ghorg = {
    enable = lib.mkEnableOption "ghorg mirror jobs managed through ghorg reclone";

    package = lib.mkPackageOption pkgs "ghorg" { };

    user = lib.mkOption {
      type = lib.types.str;
      default = "ghorg";
      description = "User account that runs ghorg.";
    };

    group = lib.mkOption {
      type = lib.types.str;
      default = "ghorg";
      description = "Primary group for the ghorg service.";
    };

    createUser = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Whether to create the ghorg system user automatically.";
    };

    createGroup = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Whether to create the ghorg system group automatically.";
    };

    dataDir = lib.mkOption {
      type = lib.types.str;
      default = "/var/lib/ghorg";
      description = ''
        Working directory for ghorg and the default clone destination for jobs
        that do not override `settings.cloneToPath`.
      '';
    };

    dataDirMode = lib.mkOption {
      type = lib.types.str;
      default = "0750";
      example = "0700";
      description = "Permissions mode used when creating `dataDir` via systemd-tmpfiles.";
    };

    startAt = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
      example = "daily";
      description = ''
        Optional systemd timer schedule in `OnCalendar=` format. Leave `null`
        to manage execution manually.
      '';
    };

    jobs = lib.mkOption {
      type = lib.types.attrsOf (
        lib.types.submodule (
          { name, ... }:
          {
            options = {
              description = lib.mkOption {
                type = lib.types.nullOr lib.types.str;
                default = null;
                description = "Optional description written into the generated reclone entry.";
              };

              postExecScript = lib.mkOption {
                type = lib.types.nullOr (lib.types.either lib.types.path lib.types.str);
                default = null;
                description = "Optional `post_exec_script` value for this reclone entry.";
              };

              args = lib.mkOption {
                type = lib.types.listOf lib.types.str;
                default = [
                  "clone"
                  name
                ];
                example = [
                  "clone"
                  "my-org"
                ];
                description = ''
                  ghorg subcommand and arguments for this job, excluding the
                  executable name. `--config` is appended automatically.
                '';
              };

              extraArgs = lib.mkOption {
                type = lib.types.listOf lib.types.str;
                default = [ ];
                example = [
                  "--preserve-dir"
                ];
                description = ''
                  Additional command-line arguments appended after `args`.
                  These override equivalent settings from `settings` or
                  `rawSettings`, because ghorg prefers CLI flags over `conf.yaml`.
                '';
              };

              configFile = lib.mkOption {
                type = lib.types.nullOr lib.types.str;
                default = null;
                description = ''
                  Existing ghorg configuration file for this job. When set, the
                  module will not generate a config from `settings` or
                  `rawSettings`.
                '';
              };

              environmentFile = lib.mkOption {
                type = lib.types.nullOr lib.types.str;
                default = null;
                description = ''
                  Optional environment file sourced by this job wrapper before
                  invoking ghorg. This is the intended place for token-related
                  GHORG_* variables.
                '';
              };

              settings = {
                scmType = lib.mkOption {
                  type = lib.types.nullOr lib.types.str;
                  default = null;
                  example = "github";
                  description = "Maps to `scm_type` in `conf.yaml`.";
                };

                hostname = lib.mkOption {
                  type = lib.types.nullOr lib.types.str;
                  default = null;
                  example = "git.example.com";
                  description = "Maps to `hostname` in `conf.yaml`.";
                };

                baseUrl = lib.mkOption {
                  type = lib.types.nullOr lib.types.str;
                  default = null;
                  example = "https://gitlab.example.com";
                  description = "Maps to `base_url` in `conf.yaml`.";
                };

                cloneProtocol = lib.mkOption {
                  type = lib.types.nullOr lib.types.str;
                  default = null;
                  example = "ssh";
                  description = "Maps to `clone_protocol` in `conf.yaml`.";
                };

                concurrency = lib.mkOption {
                  type = lib.types.nullOr lib.types.ints.positive;
                  default = null;
                  description = "Maps to `concurrency` in `conf.yaml`.";
                };

                preserveDir = lib.mkOption {
                  type = lib.types.nullOr lib.types.bool;
                  default = null;
                  description = "Maps to `preserve_dir` in `conf.yaml`.";
                };

                skipArchived = lib.mkOption {
                  type = lib.types.nullOr lib.types.bool;
                  default = null;
                  description = "Maps to `skip_archived` in `conf.yaml`.";
                };

                skipForks = lib.mkOption {
                  type = lib.types.nullOr lib.types.bool;
                  default = null;
                  description = "Maps to `skip_forks` in `conf.yaml`.";
                };

                includeSubgroups = lib.mkOption {
                  type = lib.types.nullOr lib.types.bool;
                  default = null;
                  description = "Maps to `include_subgroups` in `conf.yaml`.";
                };

                branch = lib.mkOption {
                  type = lib.types.nullOr lib.types.str;
                  default = null;
                  description = "Maps to `branch` in `conf.yaml`.";
                };

                cloneToPath = lib.mkOption {
                  type = lib.types.nullOr lib.types.str;
                  default = null;
                  description = ''
                    Maps to `absolute_path_to_clone_to` in `conf.yaml`. Defaults
                    to the service `dataDir`.
                  '';
                };
              };

              rawSettings = lib.mkOption {
                type = lib.types.attrsOf lib.types.anything;
                default = { };
                example = {
                  bitbucket_server = true;
                };
                description = ''
                  Additional ghorg config keys written directly into the
                  generated `conf.yaml`. This layer overrides keys produced from
                  `settings`.
                '';
              };
            };
          }
        )
      );
      default = { };
      description = ''
        Set of ghorg jobs. Each job is rendered into a dedicated config and a
        generated reclone entry. A single ordinary clone run is modeled as a
        single job.
      '';
    };
  };

  config = lib.mkIf cfg.enable {
    assertions = [
      {
        assertion = lib.hasPrefix "/" cfg.dataDir;
        message = "services.ghorg.dataDir must be an absolute path.";
      }
      {
        assertion = builtins.match "[0-7]{4}" cfg.dataDirMode != null;
        message = "services.ghorg.dataDirMode must be a four-digit octal mode string such as 0750.";
      }
      {
        assertion = cfg.jobs != { };
        message = "services.ghorg.jobs must define at least one job.";
      }
    ]
    ++ lib.flatten (
      lib.mapAttrsToList (name: job: [
        {
          assertion = job.args != [ ];
          message = "services.ghorg.jobs.${name}.args must not be empty.";
        }
        {
          assertion = job.configFile == null || lib.hasPrefix "/" job.configFile;
          message = "services.ghorg.jobs.${name}.configFile must be null or an absolute path.";
        }
        {
          assertion = job.environmentFile == null || lib.hasPrefix "/" job.environmentFile;
          message = "services.ghorg.jobs.${name}.environmentFile must be null or an absolute path.";
        }
        {
          assertion = job.settings.cloneToPath == null || lib.hasPrefix "/" job.settings.cloneToPath;
          message = "services.ghorg.jobs.${name}.settings.cloneToPath must be null or an absolute path.";
        }
        {
          assertion = job.configFile == null || !(hasInlineConfig job);
          message = "services.ghorg.jobs.${name} cannot set configFile together with settings or rawSettings.";
        }
      ]) cfg.jobs
    );

    users.groups = lib.mkIf cfg.createGroup {
      ${cfg.group} = { };
    };

    users.users = lib.mkIf cfg.createUser {
      ${cfg.user} = {
        isSystemUser = true;
        group = cfg.group;
        home = cfg.dataDir;
        createHome = false;
      };
    };

    systemd.tmpfiles.rules = [
      "d ${cfg.dataDir} ${cfg.dataDirMode} ${cfg.user} ${cfg.group} -"
    ];

    systemd.services.ghorg = {
      description = "Mirror repositories with ghorg";
      after = [ "network-online.target" ];
      wants = [ "network-online.target" ];
      path = [
        pkgs.git
        pkgs.openssh
      ];
      serviceConfig = {
        Type = "oneshot";
        User = cfg.user;
        Group = cfg.group;
        WorkingDirectory = cfg.dataDir;
        Environment = [
          "HOME=${cfg.dataDir}"
          "GHORG_RECLONE_PATH=${recloneConfig}"
        ];
        ExecStart = lib.escapeShellArgs [
          (lib.getExe cfg.package)
          "reclone"
        ];
      };
    };

    systemd.timers.ghorg = lib.mkIf (cfg.startAt != null) {
      description = "Run ghorg on a schedule";
      wantedBy = [ "timers.target" ];
      partOf = [ "ghorg.service" ];
      timerConfig = {
        OnCalendar = cfg.startAt;
        Unit = "ghorg.service";
      };
    };
  };
}
