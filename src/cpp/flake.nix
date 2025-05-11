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
          arch = builtins.elemAt (builtins.split "-" system) 0;
          pkgs = import nixpkgs { inherit system; };
          pkg =
            libc: attrs:
            pkgs.stdenv.mkDerivation (
              rec {
                pname = "hello-${name}-${libc}";
                version = "1.0";
                src =
                  with pkgs.lib.fileset;
                  toSource {
                    root = ../.;
                    fileset = union ./. ../check.sh;
                  };
                sourceRoot = "${src.name}/${name}";
                nativeBuildInputs = [ ];
                doCheck = true;
                buildPhase = "echo 'Building with musl'; exit 1";
                checkPhase = "../check.sh";
                installPhase = "mkdir -p $out/bin; mv hello $out/bin/hello-${name}-${libc}";
              }
              // attrs
            );
        in
        {
          "${name}-musl" = pkg "musl" {
            nativeBuildInputs = [ pkgs.zig ];
            buildPhase = ''
              export ZIG_GLOBAL_CACHE_DIR="$(mktemp -d)"

              zig c++ -target ${arch}-linux-musl -Os -static -s main.cpp -o hello
            '';
          };
          "${name}-glibc" = pkg "glibc" {
            nativeBuildInputs = [
              pkgs.gcc
              pkgs.glibc.static
            ];
            buildPhase = ''
              ${pkgs.gcc}/bin/g++ -Os -static -s main.cpp -o hello
            '';
          };
        }
      );
    };
}
