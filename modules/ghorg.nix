{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.services.ghorg;

  execArgs =
    lib.optional (cfg.command != "") cfg.command
    ++ lib.optionals (cfg.configFile != null) [
      "--config"
      cfg.configFile
    ]
    ++ cfg.extraArgs;

  execStart = lib.escapeShellArgs ([ (lib.getExe cfg.package) ] ++ execArgs);
in
{
  options.services.ghorg = {
    enable = lib.mkEnableOption "ghorg mirror service";

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
        Working directory for ghorg. This is typically the mirror root and
        where state files such as reclone metadata live.
      '';
    };

    configFile = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
      description = ''
        Path to a ghorg configuration file. This should usually point to a
        runtime file since it contains private details.
      '';
    };

    environmentFile = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
      description = ''
        Optional systemd environment file used to inject GHORG_* variables or
        secret file paths at runtime.
      '';
    };

    command = lib.mkOption {
      type = lib.types.str;
      default = "clone";
      description = ''
        ghorg subcommand to run, for example `clone`. Set to an empty string to
        invoke the binary without a subcommand.
      '';
    };

    extraArgs = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ ];
      example = [
        "--preserve-dir"
        "--scm-dir"
        "github"
      ];
      description = "Additional arguments appended to the ghorg command line.";
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
  };

  config = lib.mkIf cfg.enable {
    assertions = [
      {
        assertion = lib.hasPrefix "/" cfg.dataDir;
        message = "services.ghorg.dataDir must be an absolute path.";
      }
      {
        assertion = cfg.configFile == null || lib.hasPrefix "/" cfg.configFile;
        message = "services.ghorg.configFile must be null or an absolute path.";
      }
      {
        assertion = cfg.environmentFile == null || lib.hasPrefix "/" cfg.environmentFile;
        message = "services.ghorg.environmentFile must be null or an absolute path.";
      }
    ];

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
      "d ${cfg.dataDir} 0750 ${cfg.user} ${cfg.group} -"
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
        Environment = [ "HOME=${cfg.dataDir}" ];
        EnvironmentFile = lib.optional (cfg.environmentFile != null) cfg.environmentFile;
        ExecStart = execStart;
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
