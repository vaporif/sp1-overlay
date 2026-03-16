{
  description = "SP1 v5 test application using sp1 overlay";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
    sp1.url = "path:..";
    systems.url = "github:nix-systems/default";
  };

  outputs = inputs: let
    overlays = [inputs.sp1.overlays.default];
    perSystemPkgs = f:
      inputs.nixpkgs.lib.genAttrs (import inputs.systems) (
        system: f (import inputs.nixpkgs {inherit overlays system;})
      );
  in {
    packages = perSystemPkgs (pkgs: {
      fibonacci-elf = pkgs.sp1."v5.2.4".buildSp1Program {
        pname = "fibonacci-program";
        src = ./.;
        cargoLock = {lockFile = ./Cargo.lock;};
      };
    });

    devShells = perSystemPkgs (pkgs: {
      default = pkgs.mkShell {
        packages = [
          pkgs.sp1."v5.2.4".cargo-prove
        ];
      };
    });
  };
}
