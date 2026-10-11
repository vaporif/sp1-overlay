{
  rustPlatform,
  lib,
  protobuf,
  makeWrapper,
  sp1-src,
  sp1-sysroot,
  sp1-core-runner-binary ? null,
  sp1-rev,
  sp1-timestamp,
  cargoLockOutputHashes ? {},
  cargoHash ? null,
  wrapperEnv ? {},
}: let
  # importCargoLock can't vendor a crate that appears as both a registry and a git
  # source with the same name-version (SP1 v6.9.0 patches); fetchCargoVendor can.
  vendorArgs =
    if cargoHash != null
    then {inherit cargoHash;}
    else {
      cargoLock = {
        lockFile = "${sp1-src}/Cargo.lock";
        outputHashes = cargoLockOutputHashes;
      };
    };
in
  rustPlatform.buildRustPackage (vendorArgs
    // rec {
      pname = "cargo-prove";
      version = (fromTOML (builtins.readFile "${src}/Cargo.toml")).workspace.package.version;
      src = sp1-src;
      buildAndTestSubdir = "crates/cli";
      doCheck = false;
      env =
        {
          VERGEN_GIT_SHA = sp1-rev;
          VERGEN_BUILD_TIMESTAMP = sp1-timestamp;
        }
        // (
          if sp1-core-runner-binary != null
          then {
            SP1_CORE_RUNNER_OVERRIDE_BINARY = "${sp1-core-runner-binary}/bin/sp1-core-executor-runner-binary";
          }
          else {}
        );
      nativeBuildInputs = [
        protobuf
        makeWrapper
      ];
      postFixup = let
        wrapperArgs =
          ["--prefix PATH : ${sp1-sysroot}/bin"]
          ++ lib.mapAttrsToList (k: v: "--set ${k} ${v}") wrapperEnv;
      in ''
        wrapProgram $out/bin/cargo-prove \
          ${lib.concatStringsSep " \\\n      " wrapperArgs}
      '';
    })
