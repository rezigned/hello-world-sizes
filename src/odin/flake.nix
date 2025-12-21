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
          arch = builtins.elemAt (builtins.split "-" system) 0;
          pkgs = import nixpkgs { inherit system; };
          musl = pkgs.pkgsMusl.musl;

          # Extra inputs
          inputs =
            {
              x86_64 = [ pkgs.nasm ];
              aarch64 = [ pkgs.llvmPackages.lld ];
            }
            ."${arch}" or (throw "Unsupported arch: ${arch}");
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
            ]
            ++ inputs;
            doCheck = true;
            buildPhase = ''
              # See https://gaultier.github.io/blog/odin_and_musl.html
              case "${system}" in
                x86_64-linux)
                  odin build main.odin -file -o:size -disable-assert -default-to-nil-allocator -no-crt -no-thread-local -out:hello
                  ;;

                aarch64-linux)
                  # The -no-crt flag is not yet supported on ARM64. So, we need to build an object file and link it manually.
                  odin build main.odin -file -target=linux_arm64 -build-mode=object

                  # Odin 1.0 no longer emits main.o directly, so we combine all generated objects into one relocatable object.
                  ld.lld -r *.o -o main.o

                  # Manually link the object file into a statically-linked binary
                  ld.lld \
                    ${musl}/lib/crt1.o \
                    ${musl}/lib/crti.o \
                    ${musl}/lib/libc.a \
                    ${musl}/lib/libm.a \
                    ${musl}/lib/crtn.o \
                    --sysroot=${musl} \
                    main.o -o hello -static
                  ;;

                *)
                  echo "Unsupported system: ${system}"
                  exit 1
                  ;;
              esac
            '';
            checkPhase = "../check.sh";
            installPhase = ''
              mkdir -p $out/bin
              mv hello $out/bin/hello-${name}
              odin version > $out/bin/hello-${name}.version
            '';
          };
        }
      );
    };
}
