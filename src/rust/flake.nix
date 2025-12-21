{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    systems.url = "github:nix-systems/default";
    rust-overlay.url = "github:oxalica/rust-overlay";
  };

  outputs =
    {
      self,
      nixpkgs,
      systems,
      rust-overlay,
    }:
    let
      name = "rust";
      eachSystem = nixpkgs.lib.genAttrs (import systems);
    in
    {
      packages = eachSystem (
        system:
        let
          overlays = [ (import rust-overlay) ];
          pkgs = import nixpkgs { inherit system overlays; };

          # x86_64 or aarch64
          arch = builtins.elemAt (builtins.split "-" system) 0;
          target = "${arch}-unknown-linux-musl";
          rustc = pkgs.rust-bin.stable.latest.minimal.override {
            targets = [ target ];
          };
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
              rustc
              pkgs.musl
            ];
            doCheck = true;
            buildPhase = ''
              export RUST_FLAGS="-C opt-level=z -C strip=symbols -C lto=true -C codegen-units=1 -C panic=abort -C target-feature=+crt-static"
              rustc $RUST_FLAGS main.rs --target ${target} -o hello
            '';
            checkPhase = "../check.sh";
            installPhase = ''
              mkdir -p $out/bin
              mv hello $out/bin/hello-${name}
              rustc --version > $out/bin/hello-${name}.version
            '';
          };
        }
      );
    };
}
