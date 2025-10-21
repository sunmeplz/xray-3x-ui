{ config, lib, pkgs, ... }:

with lib;

let
  cfg = config.services.xray-3x-ui;

  # Minimum Go version required for building
  minGoVersion = "1.25.1";

  xray-3x-ui =
    assert lib.assertMsg
      (lib.versionAtLeast pkgs.go.version minGoVersion)
      "3x-ui requires Go >= ${minGoVersion}, but ${pkgs.go.version} is available";

    pkgs.buildGoModule rec {
      pname = "3x-ui";
      version = "2.8.4";

      src = pkgs.fetchFromGitHub {
        owner = "MHSanaei";
        repo = "3x-ui";
        rev = "v${version}";
        hash = "sha256-twTCFFpKBU8Sw+8f9Z4VkF9Xaf37XRH5G1dkr97/dzA=";
      };

      vendorHash = "sha256-lKmajeHEHEv47QWWJVgd3Me31lubJKKWIpdTvpgQm3c=";

      ldflags = [ "-s" "-w" ];

      meta = with lib; {
        description = "Xray panel supporting multi-protocol multi-user";
        homepage = "https://github.com/MHSanaei/3x-ui";
        license = licenses.gpl3Only;
        platforms = platforms.linux;
        maintainers = [ ];
      };
    };

in {
  # Service configuration options
  options.services.xray-3x-ui = {
    enable = mkEnableOption "3x-ui Xray panel";

    port = mkOption {
      type = types.port;
      default = 2053;
      description = lib.mdDoc "Port for the web interface.";
    };

    dataDir = mkOption {
      type = types.path;
      default = "/var/lib/3x-ui";
      description = lib.mdDoc "Directory to store 3x-ui data.";
    };

    openFirewall = mkOption {
      type = types.bool;
      default = false;
      description = lib.mdDoc "Whether to open the firewall port for the web interface.";
    };
  };

  # Service implementation
  config = mkIf cfg.enable {
    # User and group configuration
    users.users.xray-3x-ui = {
      isSystemUser = true;
      group = "xray-3x-ui";
      description = "3x-ui service user";
    };

    users.groups.xray-3x-ui = { };

    # Directory structure
    systemd.tmpfiles.rules = [
      "d ${cfg.dataDir} 0755 xray-3x-ui xray-3x-ui -"
      "d ${cfg.dataDir}/bin 0755 xray-3x-ui xray-3x-ui -"
      "d ${cfg.dataDir}/logs 0755 xray-3x-ui xray-3x-ui -"
    ];

    # Systemd service
    systemd.services.xray-3x-ui = {
      description = "3x-ui Xray Panel";
      after = [ "network.target" ];
      wantedBy = [ "multi-user.target" ];

      environment = {
        XUI_DB_FOLDER = cfg.dataDir;
        XUI_BIN_FOLDER = "${cfg.dataDir}/bin";
        XUI_LOG_FOLDER = "${cfg.dataDir}/logs";
      };

      preStart = ''
        # Symlink xray-core binary to expected location
        ln -sf ${pkgs.xray}/bin/xray ${cfg.dataDir}/bin/xray-linux-amd64
      '';

      serviceConfig = {
        Type = "simple";
        ExecStart = "${xray-3x-ui}/bin/3x-ui";
        WorkingDirectory = cfg.dataDir;
        Restart = "on-failure";
        RestartSec = "10s";

        # Security: Run as dedicated user
        User = "xray-3x-ui";
        Group = "xray-3x-ui";
        StateDirectory = "3x-ui 3x-ui/bin 3x-ui/logs";
        StateDirectoryMode = "0755";

        # Network capabilities for binding to privileged ports
        AmbientCapabilities = [ "CAP_NET_BIND_SERVICE" "CAP_NET_ADMIN" ];
        CapabilityBoundingSet = [ "CAP_NET_BIND_SERVICE" "CAP_NET_ADMIN" ];
      };
    };

    # Firewall configuration
    networking.firewall.allowedTCPPorts = mkIf cfg.openFirewall [ cfg.port ];

    # Add to system packages for CLI access
    environment.systemPackages = [ xray-3x-ui ];
  };
}
