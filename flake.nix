{
  description = "Herbage";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs";
    flake-parts.url = "github:hercules-ci/flake-parts";
  };

  outputs = inputs@{ flake-parts, nixpkgs, ... }:
    let
      flake = flake-parts.lib.mkFlake { inherit inputs; } {
        imports = [ ];

        systems =
          [ "x86_64-linux" "aarch64-darwin" "x86_64-darwin" "aarch64-linux" ];
        perSystem = { config, system, self', ... }:
          let
            pkgs = import inputs.nixpkgs { inherit system; };
            subDirectory = dir: src:
              pkgs.runCommand "subdir-${dir}" { } ''
                mkdir $out
                cp -r ${src}/${dir}/* $out
              '';

          in {
            # This is a custom version of hackage-repo-tool that allows setting
            # all signatures to never expire.
            packages.hackage-repo-tool = (pkgs.haskell.lib.overrideSrc
              pkgs.haskell.packages.ghc928.hackage-repo-tool {
                src = subDirectory "hackage-repo-tool" (pkgs.fetchFromGitHub {
                  owner = "seungheonoh";
                  repo = "hackage-security";
                  rev = "d4f07a3d6a00194615273c91322217878b4a699d";
                  hash = "sha256-gL+k4HXzS/JljMrljuX39G6/BeCrtHZuBPD8xdyMFgk=";
                });
              });
          };
      };
    in flake // { lib = (import ./lib.nix) flake; };
}
