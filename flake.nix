{
  description = "Nix packages for SP1 (Succinct Labs zero-knowledge proof system)";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
    systems.url = "github:nix-systems/default";
  };

  outputs = inputs: let
    versions = import ./lib/versions.nix;
    overlays = [inputs.self.overlays.default];
    perSystemPkgs = f:
      inputs.nixpkgs.lib.genAttrs (import inputs.systems) (
        system: f (import inputs.nixpkgs {inherit overlays system;})
      );
  in {
    overlays.default = import ./overlay.nix;

    lib.mkSp1Packages = import ./lib/mkSp1Packages.nix;

    packages = perSystemPkgs (pkgs: let
      default = pkgs.sp1.${versions.default-version};
    in {
      cargo-prove = default.cargo-prove;
      sp1-rust-toolchain = default.sp1-rust-toolchain;
      sp1-host-std = default.sp1-host-std;
      sp1-sysroot = default.sp1-sysroot;
      default = default.cargo-prove;

      # v5
      cargo-prove-v5 = pkgs.sp1."v5.2.4".cargo-prove;
      sp1-rust-toolchain-v5 = pkgs.sp1."v5.2.4".sp1-rust-toolchain;
    });

    devShells = perSystemPkgs (pkgs: {
      default = pkgs.mkShell {
        packages = [
          pkgs.cargo
          pkgs.sp1.${versions.default-version}.cargo-prove
          pkgs.sp1.${versions.default-version}.sp1-rust-toolchain
        ];
      };
    });

    formatter = perSystemPkgs (pkgs: pkgs.alejandra);
  };
}
