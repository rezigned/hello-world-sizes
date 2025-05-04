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
      version = "1.24";
      eachSystem = nixpkgs.lib.genAttrs (import systems);
    in
    {
      packages = eachSystem (
        system:
        let
          pkgs = import nixpkgs { inherit system; };
          gopkg = pkgs.go_1_24;
          arch = builtins.elemAt (builtins.split "-" system) 0;
          os = builtins.elemAt (builtins.split "-" system) 1;
        in
        {
          go = pkgs.stdenv.mkDerivation {
            pname = "hello-go";
            version = version;
            src = ./.;
            nativeBuildInputs = [ gopkg ];
            buildPhase = ''
              export CGO_ENABLED=0
              export GOCACHE=$(mktemp -d)

              go build -ldflags="-s -w" -o hello-go main.go
            '';
            installPhase = "mkdir -p $out/bin; mv hello-go $out/bin/hello-go";
          };
        }
      );
    };
}
