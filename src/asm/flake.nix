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
      name = "asm";
      eachSystem = nixpkgs.lib.genAttrs (import systems);
    in
    {
      packages = eachSystem (
        system:
        let
          pkgs = import nixpkgs { inherit system; };
          arch = builtins.elemAt (builtins.split "-" system) 0;
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
            nativeBuildInputs = [ pkgs.nasm ];
            doCheck = true;
            buildPhase = ''
              case "${system}" in
                # Build for Linux x86_64 and ARM64
                x86_64-linux | aarch64-linux)
                  nasm -f elf64 main-${system}.asm -o hello_asm.o

                  # Link the object file
                  ld -o hello hello_asm.o --entry=_start
                  ;;

                # Build for macOS
                x86_64-darwin | aarch64-darwin)
                  nasm -f macho64 main-${system}.asm -o hello_asm.o

                  # Link the object file using ld for macOS
                  ld -macosx_version_min 10.13.0 -L $(xcrun --show-sdk-path)/usr/lib -no_pie -lSystem -arch ${arch} hello_asm.o -o hello
                  ;;

                *)
                  echo "Unsupported system: ${system}"
                  exit 1
                  ;;
              esac
            '';
            checkPhase = "../check.sh";
            installPhase = ''mkdir -p $out/bin; mv hello $out/bin/hello-${name}'';
          };
        }
      );
    };
}
