{
  description = "Herbage";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs";
    flake-parts.url = "github:hercules-ci/flake-parts";
  };

  outputs = inputs@{ self, flake-parts, nixpkgs, ... }:
    let
      flake = flake-parts.lib.mkFlake { inherit inputs; } {
        imports = [ ];

        systems =
          [ "x86_64-linux" "aarch64-darwin" "x86_64-darwin" "aarch64-linux" ];
        perSystem = { config, system, self', ... }:
          let
            pkgs = import inputs.nixpkgs { inherit system; };
            herbage = import ./lib.nix { inherit pkgs; };

          in {
            # This is a custom version of hackage-repo-tool that allows setting
            # all signatures to never expire.
            packages.hackage-repo-tool = herbage.hackage-repo-tool;
          };
      };
    in flake // { lib = import ./lib.nix; };
}
