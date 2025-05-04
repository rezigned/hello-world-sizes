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
      name = "v";
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
              pkgs.vlang
              pkgs.glibc.static
            ];
            doCheck = true;
            buildPhase = ''
              export VCACHE=$(mktemp -d)/cache
              mkdir -p $VCACHE

              # Compile
              ${pkgs.vlang}/bin/v -prod -cflags "-static" -o hello main.v
            '';
            checkPhase = "../check.sh";
            installPhase = "mkdir -p $out/bin; mv hello $out/bin/hello-${name}";
          };
        }
      );
    };
}
