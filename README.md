# Herbage

Generate file-based hackage with Nix. Inspired by `input-output-hk/foliage`, but made to be 
small and to be used with Nix.

## How it works
1. Pulls all the listed packages
2. Generate sdist tarball with `cabal-install`
3. Generate staticly rendered hackage with `hackage-repo-tool`

It is using modified version of `hackage-repo-tool`(at `seungheonoh/hackage-security`) so that
it creates hackage with no root and snapshot signature expiration and to make resulting tarball
obey provided timestamp.

## Example
https://github.com/seungheonoh/herbage_test - https://seungheonoh.github.io/herbage_test/root.json
