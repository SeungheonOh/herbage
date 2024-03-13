{pkgs}:
let
  subDirectory = dir: src:
    pkgs.runCommand "subdir-${dir}" {} ''
      mkdir $out
      cp -r ${src}/${dir}/* $out
    '';
in
{
  foo = {
    "0-0" = ./testpkg;
  };
  liqwid-plutarch-extra = {
    "3.21.1" =
      subDirectory "liqwid-plutarch-extra" (
        pkgs.fetchFromGitHub {
          owner = "liqwid-labs";
          repo = "liqwid-libs";
          rev = "77fb7a3be189ff05646245df2a245d52296e1aa0";
          hash = "sha256-veVK9PMPaKxLbsYJyoMpQDJvBNLJecg61zxMazY5TV0=";
        });
  };
  plutarch-extra = {
    "1.2.1" =
      subDirectory "plutarch-extra" (
        pkgs.fetchFromGitHub {
          owner = "plutonomicon";
          repo = "plutarch-plutus";
          rev = "8d6ca9e5ec8425c2f52faf59a4737b4fd96fb01b";
          hash = "sha256-CIUbOt1uSz8MgdcuGce/AoTSA1BRKWlqrxhNPFUayj4=";
        });
  };
  plutarch = {
    "1.4.0" =
      pkgs.fetchFromGitHub {
        owner = "plutonomicon";
        repo = "plutarch-plutus";
        rev = "8d6ca9e5ec8425c2f52faf59a4737b4fd96fb01b";
        hash = "sha256-dMdJxXiBJV7XSInGeSR90/sTWHTxBm3DLaCzpN1SER0=";
      };
    "1.5.0" =
      pkgs.fetchFromGitHub {
        owner = "plutonomicon";
        repo = "plutarch-plutus";
        rev = "3ad180895aba3e24b5e1909d8b185f7286356f75";
        hash = "sha256-CIUbOt1uSz8MgdcuGce/AoTSA1BRKWlqrxhNPFUayj4=";
      };
  };
}
