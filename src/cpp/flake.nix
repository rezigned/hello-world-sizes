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
      name = "cpp";
      eachSystem = nixpkgs.lib.genAttrs (import systems);
    in
    {
      packages = eachSystem (
        system:
        let
          pkgs = import nixpkgs { inherit system; };
          pkg =
            libc:
            let
              toolchain =
                {
                  musl = {
                    gcc = pkgs.pkgsCross.musl64.gcc;
                    inputs = [ ];
                  };
                  glibc = {
                    gcc = pkgs.gcc;
                    inputs = [ pkgs.glibc.static ];
                  };
                }
                ."${libc}" or (throw "Unsupported libc: ${libc}");
            in
            pkgs.stdenv.mkDerivation rec {
              pname = "hello-${name}-${libc}";
              version = "1.0";
              src =
                with pkgs.lib.fileset;
                toSource {
                  root = ../.;
                  fileset = union ./. ../check.sh;
                };
              sourceRoot = "${src.name}/${name}";
              nativeBuildInputs = [
                toolchain.gcc
              ] ++ toolchain.inputs;
              doCheck = true;
              buildPhase = ''
                ${toolchain.gcc}/bin/g++ -Os -static -s main.cpp -o hello
              '';
              checkPhase = "../check.sh";
              installPhase = "mkdir -p $out/bin; mv hello $out/bin/hello-${name}-${libc}";
            };
        in
        {
          "${name}-musl" = pkg "musl";
          "${name}-glibc" = pkg "glibc";
        }
      );
    };
}
