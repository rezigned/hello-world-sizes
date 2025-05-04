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
      name = "lang";
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
            nativeBuildInputs = [ ];

            # Build the binary (output: ./hello)
            buildPhase = ''
              # Example build command
              # ${pkgs.gcc}/bin/gcc -Os -static -s main.c -o hello
            '';

            # Install the binary (./bin/hello-{lang})
            installPhase = ''mkdir -p $out/bin; mv hello $out/bin/hello-${name}'';
          };
        }
      );
    };
}
