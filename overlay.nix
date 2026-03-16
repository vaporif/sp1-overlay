final: prev: let
  versions = import ./lib/versions.nix;
  mkSp1Packages = import ./lib/mkSp1Packages.nix;

  # Build package sets for all registered versions
  versionPackages =
    builtins.mapAttrs (
      version: config:
        if version == "default-version"
        then null
        else
          mkSp1Packages {
            pkgs = prev;
            versionConfig = config;
          }
    )
    versions;

  # Remove the default-version key
  sp1 = builtins.removeAttrs versionPackages ["default-version"];

  # Backwards-compatible aliases from default version
  defaultPkgs = sp1.${versions.default-version};
in {
  inherit sp1;

  # Backwards-compatible top-level aliases
  inherit (defaultPkgs) cargo-prove sp1-rust-toolchain sp1-host-std sp1-sysroot buildSp1Program;
}
