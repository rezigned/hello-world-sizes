{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    systems.url = "github:nix-systems/default";

    # Relative path requires Nix 2.26+. (See https://nix.dev/manual/nix/2.28/release-notes/rl-2.26)
    #
    # TODO: Since flake 'inputs' are static, this requires significant boilerplate for each sub-flake.
    # We may need to use 'flake-parts' module to avoid this repetitive 'follows' and allow
    # sub-flakes to inherit inputs from the root context.
    asm = {
      url = "path:./src/asm";
      inputs = {
        nixpkgs.follows = "nixpkgs";
        systems.follows = "systems";
      };
    };
    c = {
      url = "path:./src/c";
      inputs = {
        nixpkgs.follows = "nixpkgs";
        systems.follows = "systems";
      };
    };
    cpp = {
      url = "path:./src/cpp";
      inputs = {
        nixpkgs.follows = "nixpkgs";
        systems.follows = "systems";
      };
    };
    crystal = {
      url = "path:./src/crystal";
      inputs = {
        nixpkgs.follows = "nixpkgs";
        systems.follows = "systems";
      };
    };
    go = {
      url = "path:./src/go";
      inputs = {
        nixpkgs.follows = "nixpkgs";
        systems.follows = "systems";
      };
    };
    nim = {
      url = "path:./src/nim";
      inputs = {
        nixpkgs.follows = "nixpkgs";
        systems.follows = "systems";
      };
    };
    odin = {
      url = "path:./src/odin";
      inputs = {
        nixpkgs.follows = "nixpkgs";
        systems.follows = "systems";
      };
    };
    rust = {
      url = "path:./src/rust";
      inputs = {
        nixpkgs.follows = "nixpkgs";
        systems.follows = "systems";
        rust-overlay = {
          url = "github:oxalica/rust-overlay";
          inputs.nixpkgs.follows = "nixpkgs";
        };
      };
    };
    v = {
      url = "path:./src/v";
      inputs = {
        nixpkgs.follows = "nixpkgs";
        systems.follows = "systems";
      };
    };
    zig = {
      url = "path:./src/zig";
      inputs = {
        nixpkgs.follows = "nixpkgs";
        systems.follows = "systems";
      };
    };
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
              kaleido
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
