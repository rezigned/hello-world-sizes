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
      name = "go";
      eachSystem = nixpkgs.lib.genAttrs (import systems);
    in
    {
      packages = eachSystem (
        system:
        let
          pkgs = import nixpkgs { inherit system; };
          arch = builtins.elemAt (builtins.split "-" system) 0;
          os = builtins.elemAt (builtins.split "-" system) 1;
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
            nativeBuildInputs = [ pkgs.go ];
            doCheck = true;
            buildPhase = ''
              export CGO_ENABLED=0
              export GOCACHE=$(mktemp -d)

              go build -ldflags="-s -w" -o hello main.go
            '';
            checkPhase = "../check.sh";
            installPhase = ''
              mkdir -p $out/bin
              mv hello $out/bin/hello-${name}
              go version > $out/bin/hello-${name}.version
            '';
          };
        }
      );
    };
}
