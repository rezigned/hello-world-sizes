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
      eachSystem = nixpkgs.lib.genAttrs (import systems);
    in
    {
      packages = eachSystem (
        system:
        let
          pkgs = import nixpkgs { inherit system; };
        in
        {
          zig = pkgs.stdenv.mkDerivation {
            pname = "hello-zig";
            version = "0.13";
            src = ./.;
            nativeBuildInputs = [ pkgs.zig_0_13 ];
            buildPhase = ''
              zig build-exe \
                --global-cache-dir $(mktemp -d) \
                -O ReleaseSmall \
                -fstrip \
                -femit-bin=hello \
                main.zig
            '';
            installPhase = "mkdir -p $out/bin; mv hello $out/bin/hello-zig";
          };
        }
      );

      #   defaultPackage = self.perSystem."${builtins.currentSystem}";
      #
      #   devShell.default = let
      #     pkgs = import nixpkgs { system = builtins.currentSystem; };
      #   in
      #   pkgs.mkShell {
      #     name = "zig-dev";
      #     packages = [ pkgs.zig ];
      #   };
    };
}
