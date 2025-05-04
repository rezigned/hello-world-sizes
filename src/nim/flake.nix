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
      # Language name e.g. "c", "rust", etc.
      name = "nim";
      eachSystem = nixpkgs.lib.genAttrs (import systems);
    in
    {
      packages = eachSystem (
        system:
        let
          pkgs = import nixpkgs { inherit system; };
        in
        {
          # Package name e.g. "c", "rust", etc.
          ${name} = pkgs.stdenv.mkDerivation rec {
            pname = "hello-${name}";
            version = "1.0";

            # Source code and script for building the binary
            src =
              with pkgs.lib.fileset;
              toSource {
                root = ../.;
                fileset = union ./. ../check.sh;
              };
            sourceRoot = "${src.name}/${name}";

            # Verify that the binary is built correctly
            doCheck = true;
            checkPhase = "../check.sh";

            # Dependencies for building the binary
            nativeBuildInputs = [
              pkgs.nim
              pkgs.glibc.static
            ];

            # Build the binary (output: ./hello)
            buildPhase = ''
              export HOME=$(mktemp -d)

              ${pkgs.nim}/bin/nim c -d:release -d:danger --opt:size \
                --passL:"-L${pkgs.glibc.static}/lib -static" -o:hello main.nim
            '';

            # Install the binary (./bin/hello-{lang})
            installPhase = ''mkdir -p $out/bin; mv hello $out/bin/hello-${name}'';
          };
        }
      );
    };
}
