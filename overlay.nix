final: prev: let
  versions = import ./lib/versions.nix;
  mkSp1Packages = import ./lib/mkSp1Packages.nix;

  sp1 = builtins.mapAttrs (
    version: config:
      mkSp1Packages {
        pkgs = prev;
        versionConfig = config;
      }
  ) (builtins.removeAttrs versions ["default-version"]);

  defaultPkgs = sp1.${versions.default-version};
in {
  inherit sp1;

  # Backwards-compatible top-level aliases
  inherit (defaultPkgs) cargo-prove sp1-rust-toolchain sp1-host-std sp1-sysroot buildSp1Program;
}
