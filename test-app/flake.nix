{
  description = "SP1 test application using sp1-nix overlay";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
    sp1-nix.url = "path:..";
    systems.url = "github:nix-systems/default";
  };

  outputs = inputs: let
    overlays = [inputs.sp1-nix.overlays.default];
    perSystemPkgs = f:
      inputs.nixpkgs.lib.genAttrs (import inputs.systems) (
        system: f (import inputs.nixpkgs {inherit overlays system;})
      );
  in {
    packages = perSystemPkgs (pkgs: {
      fibonacci-elf = pkgs.buildSp1Program {
        pname = "fibonacci-program";
        src = ./.;
        cargoLock = {lockFile = ./Cargo.lock;};
      };
    });

    devShells = perSystemPkgs (pkgs: {
      default = pkgs.mkShell {
        packages = [
          pkgs.cargo-prove
        ];
      };
    });
  };
}
