{
  description = "A very basic flake";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs";

    flake-parts.url = "github:hercules-ci/flake-parts";

    "plutarch-extra-1.2.1".url =
      "github:plutonomicon/plutarch-plutus?rev=8d6ca9e5ec8425c2f52faf59a4737b4fd96fb01b";
  };

  outputs = inputs@{ flake-parts, nixpkgs, ... }:
    flake-parts.lib.mkFlake { inherit inputs; } {
      imports = [];

      systems = [ "x86_64-linux" "aarch64-darwin" "x86_64-darwin" "aarch64-linux" ];
      perSystem = { config, system, lib, self', ... }:
        let
          pkgs = import inputs.nixpkgs {
            inherit system;
          };

          sources = (import ./sources.nix) {inherit pkgs;};

          subDirectory = dir: src:
            pkgs.runCommand "subdir-${dir}" {} ''
              mkdir $out
              cp -r ${src}/${dir}/* $out
            '';

          mkSdist = name: version: hPkgSource:
            let
              cabalFiles =
                builtins.concatLists
                  (lib.mapAttrsToList
                    (name: type:
                      if type == "regular" && lib.hasSuffix ".cabal" name
                      then [ name ]
                      else []
                    )
                    (builtins.readDir hPkgSource));

              cabalFile =
                if builtins.length cabalFiles == 1
                then "${hPkgSource}/${builtins.head cabalFiles}"
                else abort "No unique cabal file exists in ${name}-${version}";

              getCabalField = field:
                let
                  lines = lib.splitString "\n" (builtins.readFile cabalFile);
                  found =
                    builtins.filter
                      (x: x != null)
                      (builtins.map
                        (line:
                          let found = builtins.match "^${field} *: *([^ ]*) *$" line;
                          in if found != null && builtins.length found == 1
                             then builtins.head found
                             else null
                        ) lines);
                in if found == [] then null else builtins.head found;

              sourceVersion =
                let
                  foundVersion = getCabalField "version";
                in
                  if foundVersion != null
                  then foundVersion
                  else abort "Cannot parse version from fetched cabal file for ${name}-${version}";

              sourceName =
                let foundName = getCabalField "name";
                in
                  if foundName != null
                  then foundName
                  else abort "Cannot parse version from fetched cabal file for ${name}-${version}";

            in
              assert
                pkgs.lib.assertMsg
                  (sourceVersion == version)
                  "Version does not match. Source say ${sourceVersion}, Configuration say ${version}";
              assert
                pkgs.lib.assertMsg
                  (sourceName == name)
                  "Name does not match. Source say ${sourceName}, Configuration say ${name}";
              pkgs.runCommand "${name}-${version}-sdist"
              {
                buildInputs = [ pkgs.cabal-install ];
              } ''
              mkdir -p /tmp/source
              mkdir -p $out
              cp -r ${hPkgSource}/* /tmp/source
              cd /tmp/source
              export CABAL_DIR=.
              cabal sdist --builddir=/tmp
              cp /tmp/sdist/* $out
              cp -r /tmp/source $out
              cp /tmp/source/*.cabal $out/${name}.cabal
              '';

          foo = sources:
            builtins.mapAttrs
              (packageName: versionSet:
                builtins.mapAttrs
                  (version: src: mkSdist packageName version src
                  )
                  versionSet
              )
              sources;

          bar = foo sources;

          mkPkgDir = sources:
            let
              copyPackages =
                builtins.concatMap
                  (packageName:
                    builtins.map
                      (version:
                        let
                          sdist = mkSdist packageName version (sources."${packageName}"."${version}");
                        in ''
                          mkdir -p $out/${packageName}-${version}
                          cp ${sdist}/*.cabal $out/${packageName}-${version}
                          cp ${sdist}/*.tar.gz $out
                        ''
                      )
                      (builtins.attrNames (sources."${packageName}"))
                  )
                  (builtins.attrNames sources);
            in
              pkgs.runCommand "hackages-packages" {}
              ''
              mkdir -p $out
              ${builtins.concatStringsSep "\n" copyPackages}
              '';

        in
          {
            packages.test = bar.foo."0-0";
            packages.foo = mkPkgDir sources;
            packages.sdist = pkgs.runCommand "combined-docs"
              {
                buildInputs = [ pkgs.cabal-install ];
              } ''
              ls /tmp > $out
              '';
          };
    };
}
