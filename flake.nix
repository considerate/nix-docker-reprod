{
  description = "Generic devshell setup";

  inputs = {
    # The nixpkgs
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

    # Utility functions
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs = { self, nixpkgs, flake-utils }:
    let
      pkgsForSys = system: import nixpkgs { inherit system; };
      perSystem = (system:
        let
          pkgs = pkgsForSys system;
        in
        {
          formatter = pkgs.nixpkgs-fmt;

          packages.hello = pkgs.stdenv.mkDerivation {
            pname = "hello";
            version = "0.1.0";
            src = ./src/hello.c;
            dontUnpack = true;
            buildPhase = ''
              $CC $src -o hello
            '';
            installPhase = ''
              mkdir -p $out/bin
              cp hello $out/bin
            '';
          };

          packages.hello-docker = pkgs.dockerTools.streamLayeredImage {
            name = "hello";
            tag = "0.1.0";
            fakeRootCommands = ''
              mkdir -p /app
            '';
            enableFakechroot = true;
            maxLayers = 2;
            config = {
              cmd = [ "${self.packages.${system}.hello}/bin/hello" ];
            };
          };

          apps.ci = flake-utils.lib.mkApp {
            drv = pkgs.writeShellScriptBin "BuildDockerImage" ''
              set -e; set -o pipefail
              $(nix build --print-out-paths --no-link --print-build-logs '.#hello-docker') \
                | docker load --quiet
            '';
          };
        });
    in
    {
      # Other system-independent attr
    } //

    flake-utils.lib.eachDefaultSystem perSystem;
}
