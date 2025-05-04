{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    systems.url = "github:nix-systems/default";
  };

  outputs =
    {
      self,
      nixpkgs,
      systems,
    }:
    let
      name = "odin";
      eachSystem = nixpkgs.lib.genAttrs (import systems);
    in
    {
      packages = eachSystem (
        system:
        let
          pkgs = import nixpkgs { inherit system; };
        in
        {
          ${name} = pkgs.stdenv.mkDerivation rec {
            pname = "hello-${name}";
            version = "1.0";
            src =
              with pkgs.lib.fileset;
              toSource {
                root = ../.;
                fileset = union ./. ../check.sh;
              };
            sourceRoot = "${src.name}/${name}";
            nativeBuildInputs = [
              pkgs.odin
              pkgs.nasm
            ];
            doCheck = true;
            buildPhase = ''
              odin build main.odin -file -o:size -disable-assert -default-to-nil-allocator -no-crt -out:hello
            '';
            checkPhase = "../check.sh";
            installPhase = "mkdir -p $out/bin; mv hello $out/bin/hello-${name}";
          };
        }
      );
    };
}
