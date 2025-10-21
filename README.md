# xray-3x-ui

NixOS module for [3x-ui](https://github.com/MHSanaei/3x-ui) - Xray panel supporting multi-protocol multi-user.

## Features

- ✅ NixOS module with declarative configuration
- ✅ Automatic user and group management
- ✅ Systemd service with proper security settings
- ✅ Firewall integration
- ✅ Go version validation (requires >= 1.25.1)

## Installation

### Using Flakes

Add to your `flake.nix`:

```nix
{
  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
    xray-3x-ui.url = "github:sunmeplz/xray-3x-ui";
  };

  outputs = { self, nixpkgs, xray-3x-ui }: {
    nixosConfigurations.yourhost = nixpkgs.lib.nixosSystem {
      system = "x86_64-linux";
      modules = [
        xray-3x-ui.nixosModules.default
        ./configuration.nix
      ];
    };
  };
}
```

### Direct Import

Download and import the module:

```nix
{ config, pkgs, ... }:

{
  imports = [
    /path/to/xray-3x-ui/module.nix
  ];
}
```

## Configuration

### Basic Configuration

```nix
services.xray-3x-ui = {
  enable = true;
  port = 2053;
  openFirewall = true;
};
```

### Advanced Configuration

```nix
services.xray-3x-ui = {
  enable = true;
  port = 2053;
  dataDir = "/var/lib/3x-ui";  # Custom data directory
  openFirewall = true;          # Open firewall for web interface
};
```

## Options

| Option | Type | Default | Description |
|--------|------|---------|-------------|
| `enable` | boolean | `false` | Enable the 3x-ui service |
| `port` | port | `2053` | Port for the web interface |
| `dataDir` | path | `/var/lib/3x-ui` | Directory to store 3x-ui data |
| `openFirewall` | boolean | `false` | Whether to open the firewall port |

## Requirements

- NixOS
- Go >= 1.25.1 (automatically validated during build)

## Access

After enabling the service, access the web interface at:

```
http://your-server-ip:2053
```

Default credentials can be found in the [3x-ui documentation](https://github.com/MHSanaei/3x-ui).

## License

MIT License - See [LICENSE](LICENSE) file for details.

Note: This license applies to the NixOS module code. The packaged 3x-ui software is licensed under GPL-3.0.

## Credits

- [3x-ui](https://github.com/MHSanaei/3x-ui) - The upstream Xray panel
- [Xray-core](https://github.com/XTLS/Xray-core) - The Xray proxy
