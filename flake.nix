{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    systems.url = "github:nix-systems/default";

    # Relative path requires Nix 2.26+. (See https://nix.dev/manual/nix/2.28/release-notes/rl-2.26)
    asm.url = "path:./src/asm";
    c.url = "path:./src/c";
    cpp.url = "path:./src/cpp";
    crystal.url = "path:./src/crystal";
    go.url = "path:./src/go";
    nim.url = "path:./src/nim";
    odin.url = "path:./src/odin";
    rust.url = "path:./src/rust";
    v.url = "path:./src/v";
    zig.url = "path:./src/zig";
  };

  outputs =
    inputs@{
      self,
      nixpkgs,
      systems,
      ...
    }:

    let
      # List of supported languages
      langs = [
        "asm"
        "c"
        "cpp"
        "go"
        "nim"
        "odin"
        "rust"
        "v"
        "zig"
      ];

      # Function to generate attributes for each system
      eachSystem =
        f:
        nixpkgs.lib.genAttrs (import systems) (
          system:
          f {
            system = system;
            pkgs = import nixpkgs { inherit system; };
          }
        );

      # Generate packages for each language and system
      packages = eachSystem (
        { system, pkgs, ... }:
        let
          python = pkgs.python3.withPackages (
            ps: with ps; [
              plotly
              numpy
              pandas
            ]
          );

          # Merge all packages from all languages
          langPackages = builtins.foldl' (acc: lang: acc // inputs.${lang}.packages.${system}) { } langs;
        in
        langPackages
        // rec {
          # Combine all language-specific packages into a single output
          all = pkgs.symlinkJoin {
            name = "hello-all";
            paths = builtins.attrValues langPackages;
          };

          # Default package for generating a report
          default = pkgs.writeShellApplication {
            name = "report";
            runtimeInputs = [
              python
              pkgs.file
              pkgs.time
            ];
            text = ''
              for bin in ${all}/bin/*; do ${pkgs.file}/bin/file "$(readlink -f "$bin")"; done

              metrics="size mem"
              for metric in $metrics; do
                ${python}/bin/python3 ./src/main.py ${all}/bin/ "$metric" ${system}
              done
            '';
          };
        }
      );
    in
    {
      formatter = eachSystem ({ system, pkgs, ... }: pkgs.nixfmt-rfc-style);

      packages = packages;

      devShells = eachSystem (
        { system, pkgs, ... }:
        {
          default = pkgs.mkShell {
            buildInputs = [ ];
            shellHook = ''echo "Hello, world!"'';
          };
        }
      );

      shellHook = ''
        echo "Development environment with specific language versions and pandas loaded!"
      '';
    };
}
