{
  description = "RISC-V development shell";
  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
  inputs.systems.url = "github:nix-systems/default";
  inputs.flake-utils = {
    url = "github:numtide/flake-utils";
    inputs.systems.follows = "systems";
  };

  outputs =
    { nixpkgs, flake-utils, ... }:
    flake-utils.lib.eachDefaultSystem (
      system:
      let
        pkgs = nixpkgs.legacyPackages.${system};
        riscv = pkgs.pkgsCross.riscv32-embedded;
      in
      {
        devShells.default = pkgs.mkShell {
          packages = [
            riscv.buildPackages.binutils
            pkgs.qemu
            pkgs.gdb
          ];
        };
      }
    );
}
