{ pkgs }:
let
  lib = pkgs.lib;
in rec {
  subDirectory = dir: src:
    pkgs.runCommand "subdir-${dir}" { } ''
      mkdir $out
      cp -r ${src}/${dir}/* $out
    '';

  hackage-repo-tool =
    (pkgs.haskell.lib.overrideSrc
      pkgs.haskell.packages.ghc928.hackage-repo-tool {
        src = subDirectory "hackage-repo-tool" (pkgs.fetchFromGitHub {
          owner = "seungheonoh";
          repo = "hackage-security";
          rev = "89c00773160ea9128ddb14a4db1e17ae21e8cf42";
          hash = "sha256-u4gnFG7JRqwNxcYoYJZdaqPEhssENp/tCMJWwhOwPIU=";
        });
      });

  mkSDist = name: version: {src, timestamp ? null, subdir ? null}:
    let
      hPkgSource =
        if subdir != null
        then "${src}/${subdir}"
        else src;

      cabalFiles = builtins.concatLists (lib.mapAttrsToList (name: type:
        if type == "regular" && lib.hasSuffix ".cabal" name then
          [ name ]
        else
          [ ]) (builtins.readDir hPkgSource));

      cabalFile = if builtins.length cabalFiles == 1 then
        "${hPkgSource}/${builtins.head cabalFiles}"
      else
        abort "No unique cabal file exists in ${name}-${version}";

      getCabalField = field:
        let
          lines = lib.splitString "\n" (builtins.readFile cabalFile);
          found = builtins.filter (x: x != null) (builtins.map (line:
            let found = builtins.match "^${field} *: *([^ ]*) *$" line;
            in if found != null && builtins.length found == 1 then
              builtins.head found
            else
              null) lines);
        in if found == [ ] then null else builtins.head found;

      sourceVersion = let foundVersion = getCabalField "version";
      in if foundVersion != null then
        foundVersion
      else
        abort
        "Cannot parse version in fetched cabal file for ${name}-${version}";

      sourceName = let foundName = getCabalField "name";
      in if foundName != null then
        foundName
      else
        abort
        "Cannot parse version in fetched cabal file for ${name}-${version}";

      updateModifiedDate =
        if timestamp != null
        then ''touch -a -m -t $(date -d "${timestamp}" +%Y%m%d%H%M.%S) $out/*''
        else "";

    in assert pkgs.lib.assertMsg (sourceVersion == version)
      "Version does not match. Source say ${sourceVersion}, Configuration say ${version}";
    assert pkgs.lib.assertMsg (sourceName == name)
      "Name does not match. Source say ${sourceName}, Configuration say ${name}";
    pkgs.runCommand "${name}-${version}-sdist" {
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
    builtins.mapAttrs (packageName: versionSet:
      builtins.mapAttrs (version: info:
        info // {sdist = mkSDist packageName version info;}
      )
      versionSet) sources;

  genHackage = keyDir: sources:
    let
      sdists = sourceToSDist sources;
      copyPackages = builtins.concatMap (packageName:
        builtins.map (version:
          let
            p = sdists."${packageName}"."${version}";
          in ''
            cp ${p.sdist}/${packageName}-${version}.tar.gz $out/package
            ${
              if p ? timestamp
              then ''
                touch -a -m -t $(date -d "${p.timestamp}" +%Y%m%d%H%M.%S) \
                  $out/package/${packageName}-${version}.tar.gz
              ''
              else ""
            }
          '') (builtins.attrNames (sdists."${packageName}")))
        (builtins.attrNames sdists);
    in pkgs.runCommand "hackages-packages" {
      buildInputs = [ hackage-repo-tool ];
    } ''
      mkdir -p $out/package
      ${builtins.concatStringsSep "\n" copyPackages}

      hackage-repo-tool bootstrap \
            --repo $out \
            --keys ${keyDir} \
            --no-expire
    '';
}
