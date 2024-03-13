{
  description = "A very basic flake";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs";

    flake-parts.url = "github:hercules-ci/flake-parts";
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

          mkSDist = name: version: hPkgSource:
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
                  else abort "Cannot parse version in fetched cabal file for ${name}-${version}";

              sourceName =
                let foundName = getCabalField "name";
                in
                  if foundName != null
                  then foundName
                  else abort "Cannot parse version in fetched cabal file for ${name}-${version}";

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

          sourceToSDist = sources:
            builtins.mapAttrs
              (packageName: versionSet:
                builtins.mapAttrs
                  (version: src:
                    mkSDist packageName version src
                  ) versionSet
              ) sources;

          bar = sourceToSDist sources;

          mkPkgDir = sources:
            let
              sdists = sourceToSDist sources;
              copyPackages =
                builtins.concatMap
                  (packageName:
                    builtins.map
                      (version:
                        let
                          sdist = sdists."${packageName}"."${version}";
                        in ''
                          mkdir -p $out/${packageName}-${version}
                          cp ${sdist}/*.cabal $out/${packageName}-${version}
                          cp ${sdist}/*.tar.gz $out
                        ''
                      )
                      (builtins.attrNames (sdists."${packageName}"))
                  )
                  (builtins.attrNames sdists);
            in
              pkgs.runCommand "hackages-packages" {}
                ''
                mkdir -p $out
                ${builtins.concatStringsSep "\n" copyPackages}
                '';

          genKeys =
            pkgs.runCommand "genKeys" {}
              ''

              '';

        in
          {
            packages.test = bar.sourceToSDist."0-0";
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
