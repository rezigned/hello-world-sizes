{
  description = "Crystal Hello World";

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
        in
        {
          crystal = pkgs.stdenv.mkDerivation {
            pname = "hello-crystal";
            version = version;
            src = ./.;
            nativeBuildInputs = [ pkgs.crystal ];
            buildPhase = ''
              crystal build main.cr -o hello --static
            '';
            installPhase = "mkdir -p $out/bin; mv hello $out/bin/hello-cr";
          };
        }
      );
    };
}
