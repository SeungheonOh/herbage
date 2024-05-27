{
  description = "Herbage";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs";
    flake-parts.url = "github:hercules-ci/flake-parts";
    haskell-nix.url = "github:input-output-hk/haskell.nix";
  };

  outputs = inputs@{ self, flake-parts, haskell-nix, nixpkgs, ... }:
    let
      flake = flake-parts.lib.mkFlake { inherit inputs; } {
        imports = [
          inputs.flake-parts.flakeModules.easyOverlay
        ];

        systems =
          [ "x86_64-linux" "aarch64-darwin" "x86_64-darwin" "aarch64-linux" ];
        perSystem = { config, system, self', ... }:
          let
            subDirectory = dir: src:
              pkgs.runCommand "subdir-${dir}" { } ''
                mkdir $out
                cp -r ${src}/${dir}/* $out
              '';
            hsPkgs =
              import haskell-nix.inputs.nixpkgs {
                inherit system;
                inherit (haskell-nix) config;
                overlays = [ haskell-nix.overlay ];
              };

            hackage-repo-tool =
              ((hsPkgs.haskell-nix.cabalProject' {
                compiler-nix-name = "ghc928";
                src = subDirectory "hackage-repo-tool" (pkgs.fetchFromGitHub {
                  owner = "seungheonoh";
                  repo = "hackage-security";
                  rev = "89c00773160ea9128ddb14a4db1e17ae21e8cf42";
                  hash = "sha256-u4gnFG7JRqwNxcYoYJZdaqPEhssENp/tCMJWwhOwPIU=";
                });
              }).flake {}).packages."hackage-repo-tool:exe:hackage-repo-tool";

            pkgs = import inputs.nixpkgs { inherit system; };
            herbage = import ./lib.nix { inherit pkgs; };

          in {
            overlayAttrs = {
              inherit (config.packages) hackage-repo-tool;
            };

            # This is a custom version of hackage-repo-tool that allows setting
            # all signatures to never expire.
            packages.hackage-repo-tool = hackage-repo-tool;
          };
      };
    in flake // { lib = import ./lib.nix; };
}
