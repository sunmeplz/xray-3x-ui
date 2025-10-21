{
  description = "NixOS module for 3x-ui Xray panel";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
  };

  outputs = { self, nixpkgs }: {
    nixosModules.default = import ./module.nix;
    nixosModules.xray-3x-ui = import ./module.nix;
  };
}